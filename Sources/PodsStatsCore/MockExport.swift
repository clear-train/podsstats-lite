import Foundation

/// 生成一份结构与 Apple 健康导出完全一致的 export.xml，用来在没有真实数据时验证逻辑。
public enum MockExport {

    public struct Config: Sendable {
        public var days: Int = 30
        public var seed: UInt64 = 20240501
        public var timeZoneOffset: Int = 8 * 3600
        /// 每天出现使用的概率
        public var usageProbability: Double = 0.85
        public var includeEnvironmental: Bool = true
        /// 节假日/周末使用更多
        public var weekendBoost: Double = 1.4

        public init() {}
    }

    /// 判定性伪随机（不依赖系统随机源，方便复现）
    private struct Rng {
        var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }

        mutating func double() -> Double {
            Double(next() % 1_000_000) / 1_000_000.0
        }

        mutating func range(_ lo: Double, _ hi: Double) -> Double {
            lo + (hi - lo) * double()
        }

        mutating func int(_ lo: Int, _ hi: Int) -> Int {
            guard hi > lo else { return lo }
            return lo + Int(next() % UInt64(hi - lo + 1))
        }
    }

    public static func generateXML(config: Config = Config()) -> String {
        var rng = Rng(seed: config.seed)
        var out = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE HealthData [
        <!ELEMENT HealthData (ExportDate,Me,(Record|Correlation|Workout|ActivitySummary|ClinicalRecord)*)>
        <!ATTLIST HealthData locale CDATA #REQUIRED>
        ]>
        <HealthData locale="zh_CN">
         <ExportDate value="\(HealthDate.format(Date(), timeZoneOffset: config.timeZoneOffset))"/>
         <Me HKCharacteristicTypeIdentifierDateOfBirth="1990-01-01" HKCharacteristicTypeIdentifierBiologicalSex="HKBiologicalSexNotSet" HKCharacteristicTypeIdentifierBloodType="HKBloodTypeNotSet" HKCharacteristicTypeIdentifierFitzpatrickSkinType="HKFitzpatrickSkinTypeNotSet"/>

        """

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        for dayOffset in stride(from: config.days - 1, through: 0, by: -1) {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: startOfToday) else { continue }
            let weekday = calendar.component(.weekday, from: dayStart)
            let isWeekend = weekday == 1 || weekday == 7
            let probability = min(1.0, config.usageProbability * (isWeekend ? config.weekendBoost : 1.0))
            if rng.double() > probability { continue }

            // 一天 1~4 段：通勤 / 午休 / 工作 / 晚上
            let sessionCount = rng.int(1, isWeekend ? 4 : 3)
            var slots: [(Int, Int)] = []
            if sessionCount >= 1 { slots.append((rng.int(8, 10), rng.int(20, 60))) }      // 通勤
            if sessionCount >= 2 { slots.append((rng.int(12, 13), rng.int(20, 50))) }     // 午休
            if sessionCount >= 3 { slots.append((rng.int(14, 18), rng.int(30, 120))) }    // 工作
            if sessionCount >= 4 { slots.append((rng.int(19, 23), rng.int(40, 150))) }    // 晚上

            for (hour, minutes) in slots {
                guard let sessionStart = calendar.date(byAdding: .hour, value: hour, to: dayStart) else { continue }
                var cursor = sessionStart.addingTimeInterval(TimeInterval(rng.int(0, 20 * 60)))
                let sessionEnd = cursor.addingTimeInterval(TimeInterval(minutes * 60))
                let baseDb = rng.range(58, 78)
                let devices = ["AirPods Pro", "AirPods Pro 2", "AirPods Max", "WH-1000XM5"]
                let device = devices[rng.int(0, devices.count - 1)]
                while cursor < sessionEnd {
                    // 偶尔摘下耳机 / 断连：留一段 2~15 分钟的空档，让 gap 参数有实际效果
                    if rng.double() < 0.06 {
                        cursor = cursor.addingTimeInterval(TimeInterval(rng.int(120, 900)))
                        if cursor >= sessionEnd { break }
                    }
                    // 每条样本覆盖 60~180 秒
                    let span = TimeInterval(rng.int(60, 180))
                    let sampleEnd = min(sessionEnd, cursor.addingTimeInterval(span))
                    guard sampleEnd > cursor else { break }
                    // 音量在基础值上下浮动，偶尔出现大声段落
                    var db = baseDb + rng.range(-8, 8)
                    if rng.double() < 0.06 { db += rng.range(10, 20) }
                    db = min(100, max(30, db))

                    out += "  <Record type=\"HKQuantityTypeIdentifierHeadphoneAudioExposure\""
                    out += " sourceName=\"\(device)\" sourceVersion=\"17.4\""
                    out += " device=\"&lt;&lt;HKDevice: 0x1, name:\(device)&gt;&gt;\""
                    out += " unit=\"dBASPL\""
                    out += " creationDate=\"\(HealthDate.format(sampleEnd, timeZoneOffset: config.timeZoneOffset))\""
                    out += " startDate=\"\(HealthDate.format(cursor, timeZoneOffset: config.timeZoneOffset))\""
                    out += " endDate=\"\(HealthDate.format(sampleEnd, timeZoneOffset: config.timeZoneOffset))\""
                    out += String(format: " value=\"%.1f\">\n", db)
                    out += "   <MetadataEntry key=\"HKMetadataKeyAudioExposureDuration\" value=\"\(Int(span))\"/>\n"
                    out += "  </Record>\n"

                    if config.includeEnvironmental, rng.double() < 0.15 {
                        out += "  <Record type=\"HKQuantityTypeIdentifierEnvironmentalAudioExposure\" sourceName=\"iPhone\" unit=\"dBASPL\""
                        out += " creationDate=\"\(HealthDate.format(sampleEnd, timeZoneOffset: config.timeZoneOffset))\""
                        out += " startDate=\"\(HealthDate.format(cursor, timeZoneOffset: config.timeZoneOffset))\""
                        out += " endDate=\"\(HealthDate.format(sampleEnd, timeZoneOffset: config.timeZoneOffset))\""
                        out += String(format: " value=\"%.1f\"/>\n", rng.range(40, 70))
                    }

                    cursor = sampleEnd
                }
            }
        }

        out += "  <Record type=\"HKQuantityTypeIdentifierStepCount\" sourceName=\"iPhone\" unit=\"count\""
        out += " creationDate=\"\(HealthDate.format(now, timeZoneOffset: config.timeZoneOffset))\""
        out += " startDate=\"\(HealthDate.format(startOfToday, timeZoneOffset: config.timeZoneOffset))\""
        out += " endDate=\"\(HealthDate.format(now, timeZoneOffset: config.timeZoneOffset))\" value=\"3210\"/>\n"
        out += "</HealthData>\n"
        return out
    }

    public static func write(to url: URL, config: Config = Config()) throws {
        let xml = generateXML(config: config)
        try xml.write(to: url, atomically: true, encoding: .utf8)
    }
}
