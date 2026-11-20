import Foundation

/// 会话内真实存在样本的连续区间
public struct SessionSpan: Sendable, Codable, Hashable {
    public var start: Date
    public var end: Date
    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

/// 一次「佩戴耳机听东西」的连续会话
public struct HeadphoneSession: Sendable, Codable {
    public var start: Date
    public var end: Date
    /// 会话内样本区间的并集时长（秒），已去掉重叠与空档
    public var duration: TimeInterval
    public var sampleCount: Int
    /// max(样本音量)，dB
    public var maxDB: Double?
    /// 按时长加权的平均音量，dB
    public var avgDB: Double?
    /// 高音量时长（>= 80 dBASPL）
    public var loudDuration: TimeInterval
    /// 极高音量时长（>= 90 dBASPL）
    public var veryLoudDuration: TimeInterval
    public var source: String?
    /// 12 档音量分布（40 dB 起、每档 5 dB，末档含 ≥95 dB），单位秒；空数组表示无音量数据
    public var dbBuckets: [Double]
    /// 会话内实际有样本的连续区间。空数组表示整段 [start, end] 都有样本
    public var spans: [SessionSpan]

    public var minutes: Double { duration / 60 }

    public init(start: Date, end: Date, duration: TimeInterval, sampleCount: Int,
                maxDB: Double?, avgDB: Double?, loudDuration: TimeInterval,
                veryLoudDuration: TimeInterval, source: String?,
                dbBuckets: [Double] = [], spans: [SessionSpan] = []) {
        self.start = start
        self.end = end
        self.duration = duration
        self.sampleCount = sampleCount
        self.maxDB = maxDB
        self.avgDB = avgDB
        self.loudDuration = loudDuration
        self.veryLoudDuration = veryLoudDuration
        self.source = source
        self.dbBuckets = dbBuckets
        self.spans = spans
    }

    /// 用于按天/按小时切分的区间列表
    public var effectiveSpans: [SessionSpan] {
        spans.isEmpty ? [SessionSpan(start: start, end: end)] : spans
    }

    /// 音量分档：40 dB 起，每 5 dB 一档，共 12 档
    public static let dbBucketCount = 12
    public static let dbBucketLower = 40.0
    public static let dbBucketWidth = 5.0

    public static func dbBucketIndex(_ db: Double) -> Int {
        let clamped = min(max(db, dbBucketLower), 100)
        return min(dbBucketCount - 1, max(0, Int((clamped - dbBucketLower) / dbBucketWidth)))
    }
}

public enum SessionBuilder {

    public struct Options: Sendable {
        /// 相邻两条样本间隔超过这个秒数就切成两次会话
        public var gap: TimeInterval
        /// 单条样本有效时长上限（超过视为脏数据）
        public var maxSampleDuration: TimeInterval
        /// 单次会话超过这个时长时做均分切段（防止把一整天零散样本并成一条）
        public var longSessionSplit: TimeInterval

        public init(gap: TimeInterval = 300,
                    maxSampleDuration: TimeInterval = 4 * 3600,
                    longSessionSplit: TimeInterval = 12 * 3600) {
            self.gap = gap
            self.maxSampleDuration = maxSampleDuration
            self.longSessionSplit = longSessionSplit
        }

        public static let `default` = Options()
    }

    /// 内部累加器，避免污染对外结构体语义
    private struct Acc {
        var start: Date
        var end: Date
        var duration: TimeInterval = 0
        var sampleCount: Int = 0
        var dbSum: Double = 0        // Σ(db × 秒)
        var dbSeconds: Double = 0    // Σ(有 db 的秒)
        var maxDB: Double?
        var loud: TimeInterval = 0
        var veryLoud: TimeInterval = 0
        var source: String?
        var buckets: [Double] = Array(repeating: 0, count: HeadphoneSession.dbBucketCount)
        var spans: [SessionSpan] = []

        var cursorEnd: Date { end }

        mutating func absorb(db: Double?, from start: Date, seconds: TimeInterval) {
            guard seconds > 0 else { return }
            duration += seconds
            let end = start.addingTimeInterval(seconds)

            // 首尾相接的样本合并成一段，只有真正断档才新开一段
            if var last = spans.last, start.timeIntervalSince(last.end) <= 1 {
                last.end = max(last.end, end)
                spans[spans.count - 1] = last
            } else {
                spans.append(SessionSpan(start: start, end: end))
            }

            guard let db else { return }
            dbSum += db * seconds
            dbSeconds += seconds
            maxDB = max(maxDB ?? db, db)
            if db >= 80 { loud += seconds }
            if db >= 90 { veryLoud += seconds }
            buckets[HeadphoneSession.dbBucketIndex(db)] += seconds
        }

        func finalized() -> HeadphoneSession {
            HeadphoneSession(
                start: start,
                end: end,
                duration: duration,
                sampleCount: sampleCount,
                maxDB: maxDB,
                avgDB: dbSeconds > 0 ? dbSum / dbSeconds : nil,
                loudDuration: loud,
                veryLoudDuration: veryLoud,
                source: source,
                dbBuckets: buckets,
                spans: spans
            )
        }
    }

    /// 把原始样本切成会话。
    ///
    /// 规则：按 start 排序顺序扫描；`sample.start - 当前会话末尾 <= gap` 就并进同一会话，
    /// 否则开新会话。时长按样本区间并集计算，重叠部分不重复计时。
    public static func build(from samples: [HeadphoneSample],
                             options: Options = .default) -> [HeadphoneSession] {
        guard !samples.isEmpty else { return [] }

        let ordered = samples.sorted { $0.start < $1.start }
        var sessions: [HeadphoneSession] = []
        var acc: Acc?

        for sample in ordered {
            let s = sample.start
            var dur = max(0, sample.end.timeIntervalSince(s))
            if dur > options.maxSampleDuration { dur = options.maxSampleDuration }
            let e = s.addingTimeInterval(dur)

            if var cur = acc, s.timeIntervalSince(cur.cursorEnd) <= options.gap {
                let addStart = max(s, cur.cursorEnd)
                let addSeconds = max(0, e.timeIntervalSince(addStart))
                cur.end = max(cur.end, e)
                cur.absorb(db: sample.db, from: addStart, seconds: addSeconds)
                cur.sampleCount += 1
                if cur.source == nil { cur.source = sample.source }
                acc = cur
            } else {
                if let cur = acc { sessions.append(cur.finalized()) }
                var fresh = Acc(start: s, end: e, source: sample.source)
                fresh.absorb(db: sample.db, from: s, seconds: dur)
                fresh.sampleCount = 1
                acc = fresh
            }
        }
        if let cur = acc { sessions.append(cur.finalized()) }

        if options.longSessionSplit > 0 {
            sessions = sessions.flatMap { splitLong($0, options: options) }
        }
        return sessions.sorted { $0.start < $1.start }
    }

    private static func splitLong(_ session: HeadphoneSession, options: Options) -> [HeadphoneSession] {
        guard session.duration > options.longSessionSplit else { return [session] }
        let chunks = Int((session.duration / options.longSessionSplit).rounded(.up))
        guard chunks > 1 else { return [session] }
        let per = session.duration / Double(chunks)
        var out: [HeadphoneSession] = []
        for i in 0..<chunks {
            var piece = session
            let lo = session.start.addingTimeInterval(per * Double(i))
            let hi = session.start.addingTimeInterval(per * Double(i + 1))
            piece.start = lo
            piece.end = hi
            piece.duration = per
            piece.sampleCount = max(1, session.sampleCount / chunks)
            piece.loudDuration = session.loudDuration / Double(chunks)
            piece.veryLoudDuration = session.veryLoudDuration / Double(chunks)
            piece.dbBuckets = session.dbBuckets.map { $0 / Double(chunks) }
            piece.spans = session.effectiveSpans.compactMap { span in
                let s = max(span.start, lo)
                let e = min(span.end, hi)
                return e > s ? SessionSpan(start: s, end: e) : nil
            }
            out.append(piece)
        }
        return out
    }
}
