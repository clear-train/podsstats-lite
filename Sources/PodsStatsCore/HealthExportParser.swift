import Foundation

/// 流式解析 Apple 健康导出文件（export.xml），只抽取耳机音频相关记录。
/// export.xml 动辄几百 MB 到数 GB，不能用 DOM，必须 SAX。
public final class HealthExportParser: NSObject {

    public struct Result: Sendable {
        public var samples: [HeadphoneSample] = []
        public var scannedRecords: Int = 0
        public var matchedRecords: Int = 0
        /// 文件里出现过的耳机相关 type 统计，便于排查「为什么没数据」
        public var typeHistogram: [String: Int] = [:]
        public var startDate: Date?
        public var endDate: Date?
    }

    public enum Constants {
        public static let headphoneQuantity = "HKQuantityTypeIdentifierHeadphoneAudioExposure"
        public static let headphoneEvent = "HKCategoryTypeIdentifierHeadphoneAudioExposureEvent"
        public static let environmental = "HKQuantityTypeIdentifierEnvironmentalAudioExposure"
        /// 只在需要时打开：环境音量（非耳机）
        public static let allKnown = [headphoneQuantity, headphoneEvent, environmental]
    }

    private let parser: XMLParser
    private var result = Result()
    private var inRecord = false
    private var pending: HeadphoneSample?
    private var pendingType: String = ""
    private var pendingMetaDuration: TimeInterval?
    private var wantEnvironmental: Bool

    /// - Parameter includeEnvironmental: 顺带统计环境音量（默认关，耳机统计不需要）
    public init(url: URL, includeEnvironmental: Bool = false) throws {
        guard let stream = InputStream(url: url) else {
            throw PodsStatsError.cannotOpen(url.path)
        }
        self.parser = XMLParser(stream: stream)
        self.wantEnvironmental = includeEnvironmental
        super.init()
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
    }

    /// 阻塞式解析，返回聚合结果
    public func parse() throws -> Result {
        let ok = parser.parse()
        if !ok, let err = parser.parserError {
            throw PodsStatsError.parseFailed(err.localizedDescription)
        }
        // 按开始时间排序，会话切分依赖有序
        result.samples.sort { $0.start < $1.start }
        result.startDate = result.samples.first?.start
        result.endDate = result.samples.map(\.end).max()
        return result
    }
}

extension HealthExportParser {

    /// 真实导出里 sourceName 常写「某某的 iPhone」，耳机型号只出现在 device 字段：
    /// `<<HKDevice: 0x2812..., name:AirPods Pro, manufacturer:Apple Inc., model:AirPods Pro, hardware:Bluetooth>>`
    /// 这里把 name 抽出来当设备名；若只是手机/手表本身，则返回 nil 让调用方回退到 sourceName。
    static func deviceName(from device: String?) -> String? {
        guard let device, let range = device.range(of: "name:") else { return nil }
        let tail = device[range.upperBound...]
        let raw = tail.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init) ?? ""
        let name = raw
            .replacingOccurrences(of: ">>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let hosts = ["iPhone", "iPad", "Apple Watch", "Mac", "健康", "Health", "iPod"]
        if hosts.contains(where: { name.localizedCaseInsensitiveContains($0) }) { return nil }
        return name
    }
}

extension HealthExportParser: XMLParserDelegate {

    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String]) {
        switch elementName {
        case "Record":
            result.scannedRecords += 1
            guard let type = attributeDict["type"] else { return }
            let relevant = type == Constants.headphoneQuantity
                || type == Constants.headphoneEvent
                || (wantEnvironmental && type == Constants.environmental)
            guard relevant else { return }

            result.typeHistogram[type, default: 0] += 1

            guard let startString = attributeDict["startDate"],
                  let start = HealthDate.parse(startString) else { return }
            let end = attributeDict["endDate"].flatMap(HealthDate.parse) ?? start

            var db: Double?
            if let value = attributeDict["value"], let parsed = Double(value) {
                db = parsed
            }
            let kind: HeadphoneSample.Kind = (type == Constants.headphoneEvent) ? .event : .quantity

            pendingType = type
            pendingMetaDuration = nil
            pending = HeadphoneSample(
                start: start,
                end: end,
                db: db,
                kind: kind,
                source: HealthExportParser.deviceName(from: attributeDict["device"])
                    ?? attributeDict["sourceName"]
            )
            inRecord = true

        case "MetadataEntry":
            guard inRecord else { return }
            guard let key = attributeDict["key"], let value = attributeDict["value"] else { return }
            if key == "HKMetadataKeyAudioExposureDuration" || key.hasSuffix("AudioExposureDuration") {
                if let seconds = Double(value) { pendingMetaDuration = seconds }
            }

        default:
            break
        }
    }

    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        guard elementName == "Record", inRecord else { return }
        inRecord = false
        guard var sample = pending else { return }
        pending = nil

        // 少数导出里 startDate==endDate，但 metadata 带了真实暴露时长 → 用 metadata 补全
        if let meta = pendingMetaDuration, sample.end <= sample.start {
            sample.end = sample.start.addingTimeInterval(meta)
        }
        pendingMetaDuration = nil

        // 过滤明显异常（负时长、超过 24h 的单条记录）
        guard sample.duration >= 0, sample.duration <= 24 * 3600 else { return }

        result.samples.append(sample)
        result.matchedRecords += 1
    }
}

public enum PodsStatsError: Error, LocalizedError {    case cannotOpen(String)
    case parseFailed(String)
    case noData(String)

    public var errorDescription: String? {
        switch self {
        case .cannotOpen(let p): return "打不开文件：\(p)"
        case .parseFailed(let m): return "XML 解析失败：\(m)"
        case .noData(let m): return m
        }
    }
}
