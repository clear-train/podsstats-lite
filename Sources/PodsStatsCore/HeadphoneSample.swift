import Foundation

/// 一条耳机音频样本（对应 Apple 健康里「耳机音量 / Headphone Audio Exposure」的一条记录）
public struct HeadphoneSample: Sendable, Codable {
    public enum Kind: UInt8, Sendable, Codable {
        /// HKQuantityTypeIdentifierHeadphoneAudioExposure —— 带 dB 值的连续音量采样
        case quantity = 0
        /// HKCategoryTypeIdentifierHeadphoneAudioExposureEvent —— 只有区间的超限事件
        case event = 1
    }

    /// 记录起点（样本覆盖区间的开始）
    public var start: Date
    /// 记录终点
    public var end: Date
    /// dBASPL 音量；事件型记录可能没有
    public var db: Double?
    /// 记录类型
    public var kind: Kind
    /// 来源设备名（AirPods Pro / iPhone …），仅用于展示
    public var source: String?

    /// 该样本覆盖的时长（秒）
    public var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }

    public init(start: Date, end: Date, db: Double?, kind: Kind = .quantity, source: String? = nil) {
        self.start = start
        self.end = end
        self.db = db
        self.kind = kind
        self.source = source
    }
}

/// Apple 健康导出里用到的时间字符串解析器
/// 格式：`2024-03-01 09:00:00 +0800`（也可能带 T 分隔）
/// 手写解析 + timegm，比 DateFormatter 快一个数量级（百万级记录量级下差异明显）
public enum HealthDate {

    public static func parse(_ string: String) -> Date? {
        // 需要至少 "yyyy-MM-dd HH:mm:ss"
        var digits = [Int](repeating: 0, count: 6)
        let n = string.count
        guard n >= 19 else { return nil }

        let buf = Array(string.utf8)
        // 允许 T 分隔，统一按位置取值，只校验数字
        func isDigit(_ b: UInt8) -> Bool { b >= 48 && b <= 57 }

        func readInt(_ offset: Int, _ len: Int) -> Int? {
            var v = 0
            for i in 0..<len {
                let b = buf[offset + i]
                guard isDigit(b) else { return nil }
                v = v * 10 + Int(b - 48)
            }
            return v
        }

        guard let year = readInt(0, 4),
              let month = readInt(5, 2),
              let day = readInt(8, 2),
              let hour = readInt(11, 2),
              let minute = readInt(14, 2),
              let second = readInt(17, 2)
        else { return nil }

        digits[0] = year; digits[1] = month; digits[2] = day
        digits[3] = hour; digits[4] = minute; digits[5] = second

        // 时区偏移：尾部 "+0800" / "-0700"，缺省按 UTC 处理
        var offsetSeconds = 0
        if buf.count >= 24 {
            let signIndex = buf.count - 5
            let signByte = buf[signIndex]
            if signByte == 43 || signByte == 45 { // + -
                guard let oh = readInt(signIndex + 1, 2), let om = readInt(signIndex + 3, 2) else {
                    return buildUTCDate(digits, offset: 0)
                }
                offsetSeconds = (oh * 3600 + om * 60) * (signByte == 45 ? -1 : 1)
            }
        }

        return buildUTCDate(digits, offset: offsetSeconds)
    }

    private static func buildUTCDate(_ d: [Int], offset: Int) -> Date? {
        var t = tm()
        t.tm_year = Int32(d[0] - 1900)
        t.tm_mon = Int32(d[1] - 1)
        t.tm_mday = Int32(d[2])
        t.tm_hour = Int32(d[3])
        t.tm_min = Int32(d[4])
        t.tm_sec = Int32(d[5])
        t.tm_isdst = 0
        let local = timegm(&t)
        guard local != -1 else { return nil }
        // 字符串里是「当地墙上时间 + 偏移」，UTC = 墙上时间 - 偏移
        return Date(timeIntervalSince1970: TimeInterval(local - offset))
    }

    /// 输出成 export.xml 里那种格式，供 mock / 回写使用
    public static func format(_ date: Date, timeZoneOffset: Int = 8 * 3600) -> String {
        let shifted = date.addingTimeInterval(TimeInterval(timeZoneOffset))
        var t = time_t(shifted.timeIntervalSince1970.rounded())
        var tmValue = tm()
        gmtime_r(&t, &tmValue)
        var buf = [CChar](repeating: 0, count: 64)
        strftime(&buf, 64, "%Y-%m-%d %H:%M:%S", &tmValue)
        let body = String(cString: buf)
        let sign = timeZoneOffset >= 0 ? "+" : "-"
        let abs = Swift.abs(timeZoneOffset)
        let hh = abs / 3600, mm = (abs % 3600) / 60
        return String(format: "%@ %@%02d%02d", body, sign, hh, mm)
    }
}
