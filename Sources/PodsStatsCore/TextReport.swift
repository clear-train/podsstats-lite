import Foundation

/// 终端文本报告（中文对齐按显示宽度算）
public enum TextReport {

    // MARK: - 显示宽度工具

    public static func displayWidth(_ s: String) -> Int {
        var width = 0
        for scalar in s.unicodeScalars {
            let v = scalar.value
            if v == 0 { continue }
            if v < 0x1100 { width += 1; continue }
            if (0x1100...0x115F).contains(v) || (0x2E80...0xA4CF).contains(v)
                || (0xAC00...0xD7A3).contains(v) || (0xF900...0xFAFF).contains(v)
                || (0xFE30...0xFE6F).contains(v) || (0xFF00...0xFF60).contains(v)
                || (0xFFE0...0xFFE6).contains(v) || (0x1F300...0x1FAFF).contains(v)
                || (0x20000...0x3FFFD).contains(v) {
                width += 2
            } else {
                width += 1
            }
        }
        return width
    }

    static func pad(_ s: String, _ width: Int, alignRight: Bool = false) -> String {
        let w = displayWidth(s)
        guard w < width else { return s }
        let padStr = String(repeating: " ", count: width - w)
        return alignRight ? padStr + s : s + padStr
    }

    /// cells + 右对齐列索引集合
    static func line(_ cells: [(String, Int)], _ alignRight: Set<Int> = []) -> String {
        var out = ""
        for (i, cell) in cells.enumerated() {
            out += pad(cell.0, cell.1, alignRight: alignRight.contains(i))
            if i < cells.count - 1 { out += "  " }
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - 格式化

    public static func hm(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h\(String(format: "%02d", m))m" }
        return "\(m)m"
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weekNames = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let w = weekNames[min(max(comps.weekday ?? 1, 1), 7)]
        return String(format: "%02d-%02d %@", comps.month ?? 0, comps.day ?? 0, w)
    }

    /// 跨度长（跨年）时带上年份，否则「09-20 → 11-20 共 812 天」会看不懂
    static func dayString(_ date: Date, calendar: Calendar, withYear: Bool) -> String {
        guard withYear else { return dayString(date, calendar: calendar) }
        let comps = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let weekNames = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let w = weekNames[min(max(comps.weekday ?? 1, 1), 7)]
        return String(format: "%04d-%02d-%02d %@", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0, w)
    }

    static func timeString(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    public static func bar(_ value: Double, max maxValue: Double, width: Int = 22) -> String {
        guard maxValue > 0 else { return "" }
        let ratio = min(1, max(0, value / maxValue))
        let filled = Int((ratio * Double(width)).rounded())
        return String(repeating: "█", count: max(0, filled))
    }

    // MARK: - 主体

    public static func render(report: StatsReport,
                              calendar: Calendar,
                              dailyLimit: Int = 14,
                              topLimit: Int = 8) -> String {
        let s = report.summary
        var out: [String] = []

        out.append("")
        out.append("  耳机使用统计 · Headphone Audio Exposure")
        out.append("  " + String(repeating: "─", count: 64))
        if let f = s.firstDate, let l = s.lastDate {
            let multiYear = s.spanDays > 366
            let a = dayString(f, calendar: calendar, withYear: multiYear)
            let b = dayString(l, calendar: calendar, withYear: multiYear)
            out.append("  数据范围  \(a) → \(b)    共 \(s.spanDays) 天")
        }
        out.append("  统计口径  相邻样本间隔 ≤ \(report.optionsDescription["gap"] ?? "300") 秒视为同一次佩戴")
        if !s.deviceNames.isEmpty {
            let top = s.deviceNames.prefix(3).joined(separator: "、")
            let extra = s.deviceNames.count > 3 ? " 等 \(s.deviceNames.count) 种" : ""
            out.append("  设备来源  \(top)\(extra)")
        }
        out.append("")

        // ---- 总览
        out.append("  ▍总览")
        let spanDays = max(s.spanDays, 1)
        let rows: [[(String, Int)]] = [
            [("累计佩戴", 14), ("佩戴次数", 14), ("使用天数", 14)],
            [(hm(s.totalDuration), 14), ("\(s.sessionCount) 次", 14), ("\(s.activeDays) / \(s.spanDays) 天", 14)],
            [("活跃日日均", 14), ("总日均", 14), ("平均单次", 14)],
            [(hm(s.averageActiveDay), 14), (hm(s.totalDuration / Double(spanDays)), 14), (hm(s.averageSession), 14)],
            [("最长单次", 14), ("连续使用", 14), ("最长连续", 14)],
            [(hm(s.longestSession), 14), ("\(s.currentStreak) 天", 14), ("\(s.longestStreak) 天", 14)]
        ]
        for (index, cells) in rows.enumerated() {
            let text = "   " + line(cells)
            out.append(index % 2 == 0 ? text : text)
            if index % 2 == 1 { out.append("") }
        }

        // ---- 听力负担
        out.append("  ▍听力负担")
        let volHeader: [(String, Int)] = [("平均音量", 14), ("峰值音量", 14), ("≥80dB 时长", 14), ("≥90dB 占比", 14)]
        out.append("   " + line(volHeader))
        let volValues: [(String, Int)] = [
            (s.averageDB.map { String(format: "%.0f dBASPL", $0) } ?? "—", 14),
            (s.peakDB.map { String(format: "%.0f dBASPL", $0) } ?? "—", 14),
            (hm(s.loudDuration), 14),
            (s.totalDuration > 0 ? String(format: "%.1f%%", s.veryLoudDuration / s.totalDuration * 100) : "—", 14)
        ]
        out.append("   " + line(volValues))
        let whoNote: String
        if let avg = s.averageDB {
            if avg < 70 {
                whoNote = "音量控制得不错（WHO 建议长期平均 < 80 dBASPL）"
            } else if avg < 80 {
                whoNote = "音量中等，注意累计时长（WHO 建议每周 < 40 小时）"
            } else {
                whoNote = "音量偏高，建议调低（WHO 建议长期平均 < 80 dBASPL）"
            }
            out.append("   " + whoNote)
        }
        out.append("")

        // ---- 最近 N 天
        if !report.days.isEmpty {
            let recent = report.days.suffix(dailyLimit)
            out.append("  ▍最近 \(recent.count) 天")
            let align: Set<Int> = [1, 2, 3, 4]
            out.append("   " + line([("日期", 11), ("时长", 8), ("次数", 6), ("均音量", 9), ("峰值", 6), ("", 22)], align))
            let maxDuration = recent.map(\.duration).max() ?? 0
            for day in recent {
                out.append("   " + line([
                    (dayString(day.date, calendar: calendar), 11),
                    (hm(day.duration), 8),
                    ("\(day.sessionCount)", 6),
                    (day.avgDB.map { String(format: "%.0f dB", $0) } ?? "—", 9),
                    (day.maxDB.map { String(format: "%.0f", $0) } ?? "—", 6),
                    (bar(day.duration, max: maxDuration), 22)
                ], align))
            }
            out.append("")
        }

        // ---- 按周
        if report.weeks.count > 1 {
            out.append("  ▍按周")
            let align: Set<Int> = [1, 2, 3]
            out.append("   " + line([("周起始", 11), ("时长", 8), ("次数", 6), ("活跃天", 8), ("", 22)], align))
            let maxWeek = report.weeks.map(\.duration).max() ?? 0
            for week in report.weeks.suffix(12) {
                out.append("   " + line([
                    (dayString(week.weekStart, calendar: calendar), 11),
                    (hm(week.duration), 8),
                    ("\(week.sessionCount)", 6),
                    ("\(week.activeDays)", 8),
                    (bar(week.duration, max: maxWeek), 22)
                ], align))
            }
            if report.weeks.count >= 2 {
                let last = report.weeks[report.weeks.count - 1]
                let prev = report.weeks[report.weeks.count - 2]
                let delta = last.duration - prev.duration
                let pct = prev.duration > 0 ? delta / prev.duration * 100 : 0
                let arrow = delta >= 0 ? "↑" : "↓"
                out.append(String(format: "   本周 %@ vs 上周 %@  %@ %@（%.0f%%）",
                                  hm(last.duration), hm(prev.duration), arrow,
                                  hm(abs(delta)), abs(pct)))
            }
            out.append("")
        }

        // ---- 一天里的分布
        out.append("  ▍一天里什么时候在听")
        var hourTotals = [Double](repeating: 0, count: 24)
        for bucket in report.hours { hourTotals[min(max(bucket.hour, 0), 23)] += bucket.duration }
        let maxHour = hourTotals.max() ?? 0
        let glyphs = ["·", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        var chart = "   "
        for h in 0..<24 {
            let ratio = maxHour > 0 ? hourTotals[h] / maxHour : 0
            let idx = Int((ratio * Double(glyphs.count - 1)).rounded())
            chart += glyphs[min(glyphs.count - 1, max(0, idx))] + " "
        }
        out.append(chart)
        var labelLine = "   "
        for h in 0..<24 {
            labelLine += h % 3 == 0 ? pad("\(h)", 2) : "  "
        }
        out.append(labelLine)
        // 峰值时段
        let ranked = (0..<24).sorted { hourTotals[$0] > hourTotals[$1] }.prefix(3)
            .filter { hourTotals[$0] > 0 }
        if !ranked.isEmpty {
            let text = ranked.map { String(format: "%02d:00（%@）", $0, hm(hourTotals[$0])) }.joined(separator: "、")
            out.append("   高峰时段  " + text)
        }
        out.append("")

        // ---- 音量分布
        let visibleBins = report.dbHistogram.filter { $0.duration > 0 }
        if !visibleBins.isEmpty {
            out.append("  ▍音量分布（按时长）")
            let maxBin = visibleBins.map(\.duration).max() ?? 0
            for bin in visibleBins {
                let marker = bin.lower >= 90 ? " ⚠" : ""
                out.append("   " + pad(bin.label + " dB", 10) + pad(hm(bin.duration), 8)
                           + bar(bin.duration, max: maxBin, width: 24) + marker)
            }
            out.append("")
        }

        // ---- Top 会话
        if topLimit > 0, !report.sessions.isEmpty {
            out.append("  ▍最长的 \(min(topLimit, report.sessions.count)) 次佩戴")
            let align: Set<Int> = [0, 3, 4, 5, 6]
            out.append("   " + line([("#", 3), ("日期", 11), ("开始", 6), ("结束", 6), ("时长", 8), ("均音量", 9), ("峰值", 6)], align))
            let top = report.sessions.sorted { $0.duration > $1.duration }.prefix(topLimit)
            for (i, session) in top.enumerated() {
                let hot = (session.maxDB ?? 0) >= 90 ? " ⚠" : ""
                out.append("   " + line([
                    ("\(i + 1)", 3),
                    (dayString(session.start, calendar: calendar), 11),
                    (timeString(session.start, calendar: calendar), 6),
                    (timeString(session.end, calendar: calendar), 6),
                    (hm(session.duration), 8),
                    (session.avgDB.map { String(format: "%.0f dB", $0) } ?? "—", 9),
                    ((session.maxDB.map { String(format: "%.0f", $0) } ?? "—") + hot, 6)
                ], align))
            }
            out.append("")
        }

        // ---- 结论
        let insights = InsightGenerator.generate(report: report, calendar: calendar)
        if !insights.isEmpty {
            out.append("  ▍结论")
            for line in insights {
                out.append("   · " + line)
            }
            out.append("")
        }

        return out.joined(separator: "\n")
    }
}
