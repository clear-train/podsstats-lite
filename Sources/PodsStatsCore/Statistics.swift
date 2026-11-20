import Foundation

public struct DailyStat: Sendable, Codable, Identifiable {
    public var date: Date
    public var duration: TimeInterval
    public var sessionCount: Int
    public var maxDB: Double?
    public var avgDB: Double?
    public var loudDuration: TimeInterval

    public var id: Date { date }
    public var minutes: Double { duration / 60 }
    public var hours: Double { duration / 3600 }
}

public struct WeekStat: Sendable, Codable, Identifiable {
    /// 该周周一 00:00
    public var weekStart: Date
    public var duration: TimeInterval
    public var sessionCount: Int
    public var activeDays: Int

    public var id: Date { weekStart }
    public var hours: Double { duration / 3600 }
}

public struct HourBucket: Sendable, Codable {
    /// 1 = 周日 … 7 = 周六（Calendar 语义）
    public var weekday: Int
    public var hour: Int
    public var duration: TimeInterval
    public var sessionCount: Int
}

public struct DbBucket: Sendable, Codable {
    public var lower: Double
    public var upper: Double
    public var duration: TimeInterval
    public var label: String { "\(Int(lower))–\(Int(upper))" }
}

public struct Summary: Sendable, Codable {
    public var totalDuration: TimeInterval = 0
    public var sessionCount: Int = 0
    public var activeDays: Int = 0
    public var spanDays: Int = 0
    public var firstDate: Date?
    public var lastDate: Date?
    public var longestSession: TimeInterval = 0
    public var averageSession: TimeInterval = 0
    public var averageActiveDay: TimeInterval = 0
    public var averageDB: Double?
    public var peakDB: Double?
    public var loudDuration: TimeInterval = 0
    public var veryLoudDuration: TimeInterval = 0
    public var sampleCount: Int = 0
    public var deviceNames: [String] = []
    /// 截至最后一天的连续使用天数
    public var currentStreak: Int = 0
    /// 历史最长连续使用天数
    public var longestStreak: Int = 0

    public var loudRatio: Double { totalDuration > 0 ? loudDuration / totalDuration : 0 }
    public var hours: Double { totalDuration / 3600 }
}

public struct StatsReport: Sendable, Codable {
    public var summary: Summary
    public var days: [DailyStat]
    public var weeks: [WeekStat]
    public var hours: [HourBucket]
    public var dbHistogram: [DbBucket]
    public var sessions: [HeadphoneSession]
    public var optionsDescription: [String: String]
}

public enum StatsEngine {

    /// 把一次会话按自然日切分，返回 (当天 0 点, 该天时长)
    public static func splitByDay(_ session: HeadphoneSession, calendar: Calendar) -> [(Date, TimeInterval)] {
        var out: [(Date, TimeInterval)] = []
        // 只统计真正有样本的区间，会话内的断档不算佩戴时间
        for span in session.effectiveSpans {
            var cursor = span.start
            let end = max(span.end, span.start)
            var guardCount = 0
            while cursor < end, guardCount < 4000 {
                guardCount += 1
                let dayStart = calendar.startOfDay(for: cursor)
                guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                let pieceEnd = min(end, dayEnd)
                let seconds = pieceEnd.timeIntervalSince(cursor)
                if seconds > 0 { out.append((dayStart, seconds)) }
                cursor = pieceEnd
            }
        }
        return out
    }

    /// 把一次会话按「星期几 + 小时」切分
    public static func splitByHourOfWeek(_ session: HeadphoneSession, calendar: Calendar) -> [(Int, Int, TimeInterval)] {
        var out: [(Int, Int, TimeInterval)] = []
        for span in session.effectiveSpans {
            var cursor = span.start
            let end = max(span.end, span.start)
            var guardCount = 0
            while cursor < end, guardCount < 10000 {
                guardCount += 1
                let comps = calendar.dateComponents([.weekday, .hour], from: cursor)
                let weekday = comps.weekday ?? 1
                let hour = comps.hour ?? 0
                // 本小时起点 → 终点
                var hc = calendar.dateComponents([.year, .month, .day, .hour], from: cursor)
                hc.minute = 0
                hc.second = 0
                let hourStart = calendar.date(from: hc) ?? cursor
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? end
                let pieceEnd = min(end, hourEnd)
                let seconds = pieceEnd.timeIntervalSince(cursor)
                if seconds > 0 { out.append((weekday, hour, seconds)) }
                cursor = pieceEnd
            }
        }
        return out
    }

    public static func compute(sessions: [HeadphoneSession],
                               samples: [HeadphoneSample]? = nil,
                               calendar: Calendar = .current,
                               options: [String: String] = [:]) -> StatsReport {
        var summary = Summary()
        var dayMap: [Date: DailyStat] = [:]
        var weekMap: [Date: WeekStat] = [:]
        var hourMap: [String: HourBucket] = [:]
        var dbSum = 0.0
        var dbSeconds = 0.0
        var deviceSeconds: [String: Double] = [:]
        var dayDbSum: [Date: Double] = [:]
        var dayDbSeconds: [Date: Double] = [:]

        for session in sessions {
            summary.totalDuration += session.duration
            summary.sessionCount += 1
            summary.longestSession = max(summary.longestSession, session.duration)
            summary.loudDuration += session.loudDuration
            summary.veryLoudDuration += session.veryLoudDuration
            summary.sampleCount += session.sampleCount
            if let db = session.maxDB { summary.peakDB = max(summary.peakDB ?? db, db) }
            if let avg = session.avgDB {
                dbSum += avg * session.duration
                dbSeconds += session.duration
            }
            if let device = session.source { deviceSeconds[device, default: 0] += session.duration }

            for (day, seconds) in splitByDay(session, calendar: calendar) {
                var stat = dayMap[day] ?? DailyStat(date: day, duration: 0, sessionCount: 0,
                                                    maxDB: nil, avgDB: nil, loudDuration: 0)
                stat.duration += seconds
                stat.loudDuration += session.duration > 0
                    ? session.loudDuration * (seconds / session.duration) : 0
                if let db = session.maxDB { stat.maxDB = max(stat.maxDB ?? db, db) }
                if let avg = session.avgDB {
                    dayDbSum[day, default: 0] += avg * seconds
                    dayDbSeconds[day, default: 0] += seconds
                }
                dayMap[day] = stat
            }

            // 会话数记在起始那天
            let startDay = calendar.startOfDay(for: session.start)
            if var stat = dayMap[startDay] {
                stat.sessionCount += 1
                dayMap[startDay] = stat
            }

            for (weekday, hour, seconds) in splitByHourOfWeek(session, calendar: calendar) {
                let key = "\(weekday)-\(hour)"
                var bucket = hourMap[key] ?? HourBucket(weekday: weekday, hour: hour,
                                                        duration: 0, sessionCount: 0)
                bucket.duration += seconds
                hourMap[key] = bucket
            }

            // 周聚合
            if let weekStart = weekStartDate(for: session.start, calendar: calendar) {
                var wk = weekMap[weekStart] ?? WeekStat(weekStart: weekStart, duration: 0,
                                                        sessionCount: 0, activeDays: 0)
                wk.duration += session.duration
                wk.sessionCount += 1
                weekMap[weekStart] = wk
            }
        }

        // 每日加权平均音量回填
        for (day, sum) in dayDbSum {
            let seconds = dayDbSeconds[day] ?? 0
            guard seconds > 0, var stat = dayMap[day] else { continue }
            stat.avgDB = sum / seconds
            dayMap[day] = stat
        }

        // 活跃天数
        let activeDays = dayMap.values.filter { $0.duration >= 60 }.count
        summary.activeDays = activeDays

        // 周活跃天数
        for (day, stat) in dayMap where stat.duration >= 60 {
            if let weekStart = weekStartDate(for: day, calendar: calendar), var wk = weekMap[weekStart] {
                wk.activeDays += 1
                weekMap[weekStart] = wk
            }
        }

        summary.averageSession = summary.sessionCount > 0
            ? summary.totalDuration / Double(summary.sessionCount) : 0
        summary.averageActiveDay = activeDays > 0
            ? summary.totalDuration / Double(activeDays) : 0
        summary.averageDB = dbSeconds > 0 ? dbSum / dbSeconds : nil
        summary.firstDate = sessions.first?.start
        summary.lastDate = sessions.map(\.end).max()
        if let f = summary.firstDate, let l = summary.lastDate {
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: f),
                                               to: calendar.startOfDay(for: l)).day ?? 0
            summary.spanDays = days + 1
        }
        // 按使用时长排序，最常用的排前面
        summary.deviceNames = deviceSeconds.sorted { $0.value > $1.value }.map(\.key)

        // 连续使用天数（当天佩戴 >= 1 分钟算使用）
        let activeDayList = dayMap.values.filter { $0.duration >= 60 }.map(\.date).sorted()
        var longest = 0
        var running = 0
        var previous: Date?
        for day in activeDayList {
            if let prev = previous,
               let next = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(next, inSameDayAs: day) {
                running += 1
            } else {
                running = 1
            }
            longest = max(longest, running)
            previous = day
        }
        summary.longestStreak = longest
        if let last = activeDayList.last,
           let tail = summary.lastDate,
           let gap = calendar.dateComponents([.day], from: calendar.startOfDay(for: last),
                                             to: calendar.startOfDay(for: tail)).day,
           gap <= 1 {
            summary.currentStreak = running
        }

        // 音量直方图 40–100 dB，5 dB 一档
        var bins: [DbBucket] = []
        var lower = 40.0
        while lower < 100 {
            bins.append(DbBucket(lower: lower, upper: lower + 5, duration: 0))
            lower += 5
        }
        if sessions.contains(where: { !$0.dbBuckets.isEmpty }) {
            // 会话已带样本级音量分档，直接汇总最准
            for session in sessions {
                for (i, seconds) in session.dbBuckets.enumerated() where i < bins.count && seconds > 0 {
                    bins[i].duration += seconds
                }
            }
        } else if let samples, !samples.isEmpty {
            // 有原始样本时按每条样本的真实音量加权，比会话均值更准
            for sample in samples {
                guard let db = sample.db, sample.duration > 0 else { continue }
                let clamped = min(max(db, 40), 99.9)
                let index = min(bins.count - 1, max(0, Int((clamped - 40) / 5)))
                bins[index].duration += sample.duration
            }
        } else {
            for session in sessions {
                guard let avg = session.avgDB else { continue }
                let clamped = min(max(avg, 40), 99.9)
                let index = min(bins.count - 1, max(0, Int((clamped - 40) / 5)))
                bins[index].duration += session.duration
            }
        }

        let hours = hourMap.values.sorted { ($0.weekday, $0.hour) < ($1.weekday, $1.hour) }
        return StatsReport(
            summary: summary,
            days: dayMap.values.sorted { $0.date < $1.date },
            weeks: weekMap.values.sorted { $0.weekStart < $1.weekStart },
            hours: hours,
            dbHistogram: bins,
            sessions: sessions,
            optionsDescription: options
        )
    }

    public static func weekStartDate(for date: Date, calendar: Calendar) -> Date? {
        var cal = calendar
        cal.firstWeekday = 2 // 周一
        guard let interval = cal.dateInterval(of: .weekOfYear, for: date) else { return nil }
        return interval.start
    }
}
