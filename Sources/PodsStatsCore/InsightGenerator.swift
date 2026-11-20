import Foundation

/// 把统计结果翻译成几句人话，CLI / HTML / iOS 共用
public enum InsightGenerator {

    public static func generate(report: StatsReport, calendar: Calendar) -> [String] {
        let s = report.summary
        var lines: [String] = []
        guard s.sessionCount > 0 else { return lines }

        // 1. 总量
        let avgPerDay = s.totalDuration / Double(max(s.spanDays, 1))
        lines.append("过去 \(s.spanDays) 天累计戴耳机 \(human(s.totalDuration))，平均每天 \(human(avgPerDay))。")

        // 2. 最常听的时间段
        if !report.hours.isEmpty {
            var hourTotals = [Double](repeating: 0, count: 24)
            for bucket in report.hours { hourTotals[min(max(bucket.hour, 0), 23)] += bucket.duration }
            if let peak = (0..<24).max(by: { hourTotals[$0] < hourTotals[$1] }), hourTotals[peak] > 60 {
                lines.append(String(format: "%02d:00–%02d:00 是你最常戴耳机的时间段，累计 %@。",
                                    peak, peak + 1, human(hourTotals[peak])))
            }
        }

        // 3. 使用最勤的星期
        if !report.days.isEmpty {
            var weekdayTotals: [Int: TimeInterval] = [:]
            for day in report.days {
                let weekday = calendar.component(.weekday, from: day.date)
                weekdayTotals[weekday, default: 0] += day.duration
            }
            let names = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            if let top = weekdayTotals.max(by: { $0.value < $1.value }), top.value > 60 {
                var line = "\(names[min(top.key, 7)])用得最多，累计 \(human(top.value))。"
                let weekend = (weekdayTotals[1] ?? 0) + (weekdayTotals[7] ?? 0)
                let workday = (2...6).reduce(0.0) { $0 + (weekdayTotals[$1] ?? 0) }
                let days = Double(s.spanDays)
                if days > 20, workday > 0, weekend > 0 {
                    let wdAvg = workday / (days * 5 / 7), weAvg = weekend / (days * 2 / 7)
                    let diff = abs(wdAvg - weAvg) / max(wdAvg, weAvg)
                    if diff < 0.12 {
                        line += "工作日和周末的日均几乎一样（各约 \(human((wdAvg + weAvg) / 2))），习惯很稳定。"
                    } else if weAvg > wdAvg {
                        line += "周末日均 \(human(weAvg))，比工作日的 \(human(wdAvg)) 更多。"
                    } else {
                        line += "工作日日均 \(human(wdAvg))，比周末的 \(human(weAvg)) 更多。"
                    }
                }
                lines.append(line)
            }
        }

        // 4. 音量
        if let avg = s.averageDB {
            let loudRatio = s.totalDuration > 0 ? s.loudDuration / s.totalDuration * 100 : 0
            let loudText = (loudRatio > 0 && loudRatio < 0.1) ? "<0.1" : String(format: "%.0f", loudRatio)
            if avg >= 80 {
                lines.append(String(format: "平均音量 %.0f dB，已经落在偏高的区间；", avg)
                             + "把音量降 10 dB，同等时长下的听力负担能降一大截。")
            } else if loudRatio >= 10 {
                lines.append(String(format: "平均音量 %.0f dB 还算克制，但有 %.0f%% 的时间超过 80 dB（合计 %@）。",
                                    avg, loudRatio, human(s.loudDuration)))
            } else {
                lines.append(String(format: "平均音量 %.0f dB，超过 80 dB 的时长只占 %@%%，整体控制得不错。",
                                    avg, loudText))
            }
        }
        if s.veryLoudDuration >= 60 {
            lines.append("有 \(human(s.veryLoudDuration))时间音量超过 90 dB，长时间这样对听力不友好。")
        }

        // 5. 最长一次
        if let longest = report.sessions.max(by: { $0.duration < $1.duration }), longest.duration > 600 {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: longest.start)
            // 跨年数据只说「2-16」会认不出是哪一年
            let multiYear = report.summary.spanDays > 366
            let dateText = multiYear
                ? String(format: "%04d-%02d-%02d %02d:%02d", comps.year ?? 0, comps.month ?? 0,
                         comps.day ?? 0, comps.hour ?? 0, comps.minute ?? 0)
                : String(format: "%d-%02d %02d:%02d", comps.month ?? 0, comps.day ?? 0,
                         comps.hour ?? 0, comps.minute ?? 0)
            lines.append("最长的一次是 \(dateText)，连续戴了 \(human(longest.duration))。")
        }

        // 6. 连续使用
        if s.longestStreak >= 7 {
            lines.append("最长连续 \(s.longestStreak) 天都在用耳机，当前已连续 \(s.currentStreak) 天。")
        }

        // 7. 周对比
        if report.weeks.count >= 2 {
            let last = report.weeks[report.weeks.count - 1]
            let prev = report.weeks[report.weeks.count - 2]
            let today = calendar.startOfDay(for: Date())
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: last.weekStart) ?? last.weekStart
            let partial = weekEnd > today
            if prev.duration > 0, !partial {
                let pct = (last.duration - prev.duration) / prev.duration * 100
                if abs(pct) >= 15 {
                    lines.append(String(format: "最近的这一周比上一周%@了 %.0f%%。",
                                        pct > 0 ? "多" : "少", abs(pct)))
                }
            }
        }

        return lines
    }

    static func human(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        let h = minutes / 60
        let m = minutes % 60
        if seconds < 60 { return "\(max(0, Int(seconds.rounded()))) 秒" }
        if h > 0 && m > 0 { return "\(h) 小时 \(m) 分" }
        if h > 0 { return "\(h) 小时" }
        return "\(m) 分钟"
    }
}
