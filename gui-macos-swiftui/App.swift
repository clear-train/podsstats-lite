import SwiftUI
import PodsStatsCore

@main
struct PodsStatsMacApp: App {
    var body: some Scene {
        WindowGroup("耳机使用统计") {
            RootView()
                .frame(minWidth: 900, minHeight: 640)
        }
        .defaultSize(width: 1040, height: 820)
        .windowToolbarStyle(.unified)
    }
}

// MARK: - 根视图

struct RootView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        ZStack {
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    model.pickFile()
                } label: {
                    Label("打开健康数据", systemImage: "folder")
                }
                .keyboardShortcut("o")
            }
            ToolbarItem(placement: .automatic) {
                if model.isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.exportHTML()
                } label: {
                    Label("导出 HTML", systemImage: "square.and.arrow.up")
                }
                .disabled(model.report == nil)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .empty:
            DropZone(onPick: { model.pickFile() }, onDrop: { model.load(url: $0) })
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text(model.statusText).font(.callout).foregroundStyle(.secondary)
            }
        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundStyle(.orange)
                Text("没能读出数据").font(.headline)
                Text(message).font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
                Button("换一个文件") { model.pickFile() }.buttonStyle(.borderedProminent)
            }
            .padding()
        case .ready:
            if let report = model.report {
                ReportView(report: report, meta: model.meta)
            }
        }
    }
}

// MARK: - 空态拖放区

struct DropZone: View {
    let onPick: () -> Void
    let onDrop: (URL) -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "airpodspro")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.tint)
            Text("把 export.xml 或 export.zip 拖进来").font(.title2.weight(.semibold))
            Text("iPhone → 健康 App → 头像 → 导出所有健康数据，把导出的 zip 直接拖到这里。\n数据只在本机解析，不会离开这台电脑。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("选择文件…", action: onPick)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(hovering ? Color.accentColor : Color.secondary.opacity(0.4))
                .padding(24)
        )
        .onDrop(of: [.fileURL], isTargeted: $hovering) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { onDrop(url) }
            }
            return true
        }
    }
}

// MARK: - 报告视图

struct ReportView: View {
    let report: StatsReport
    let meta: AppModel.Meta

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                insights
                MetricsGrid(report: report)
                DailyBars(report: report)
                HStack(alignment: .top, spacing: 18) {
                    HeatGrid(report: report)
                    VolumeBars(report: report)
                }
                SessionTable(report: report)
                footer
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("耳机使用统计").font(.largeTitle.weight(.bold))
            Text("\(meta.fileName)　·　\(meta.spanText)　·　\(meta.sampleText)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var insights: some View {
        let lines = InsightGenerator.generate(report: report, calendar: .current)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(lines.indices, id: \.self) { i in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                        .padding(.top, 1)
                    Text(lines[i]).font(.callout)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }

    private var footer: some View {
        Text("统计口径：相邻音频样本间隔 ≤ \(report.optionsDescription["gap"] ?? "300") 秒算同一次佩戴；时长按样本区间并集计算。")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }
}

// MARK: - 指标卡

struct MetricsGrid: View {
    let report: StatsReport

    var body: some View {
        let s = report.summary
        let items: [(String, String, String)] = [
            ("累计佩戴", fmtDuration(s.totalDuration), "\(s.spanDays) 天窗口"),
            ("佩戴次数", "\(s.sessionCount)", "平均 \(fmtDuration(s.averageSession))"),
            ("使用天数", "\(s.activeDays)", "连续 \(s.currentStreak) 天"),
            ("活跃日日均", fmtDuration(s.averageActiveDay), "最长单次 \(fmtDuration(s.longestSession))"),
            ("平均音量", s.averageDB.map { String(format: "%.0f dB", $0) } ?? "—",
             "峰值 \(s.peakDB.map { String(format: "%.0f", $0) } ?? "—")"),
            ("≥80 dB", fmtDuration(s.loudDuration),
             String(format: "占 %.0f%%", s.totalDuration > 0 ? s.loudDuration / s.totalDuration * 100 : 0))
        ]
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
            ForEach(items.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 3) {
                    Text(items[i].0).font(.caption).foregroundStyle(.secondary)
                    Text(items[i].1).font(.title3.weight(.semibold)).monospacedDigit()
                    Text(items[i].2).font(.caption2).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - 每日柱状

struct DailyBars: View {
    let report: StatsReport

    var body: some View {
        let days = Array(report.days.suffix(60))
        let maxValue = max(days.map(\.duration).max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 8) {
            Text("每日佩戴时长").font(.headline)
            if days.isEmpty {
                Text("无数据").font(.callout).foregroundStyle(.secondary)
            } else {
                GeometryReader { geo in
                    let spacing: CGFloat = days.count > 30 ? 1.5 : 4
                    let width = (geo.size.width - spacing * CGFloat(days.count - 1)) / CGFloat(days.count)
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(days.indices, id: \.self) { i in
                            let day = days[i]
                            let height = max(1, geo.size.height * day.duration / maxValue)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.accentColor.opacity(isWeekend(day.date) ? 0.45 : 1))
                                .frame(width: max(1, width), height: height)
                                .help("\(dayLabel(day.date))　\(fmtDuration(day.duration))　\(day.sessionCount) 次")
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: 150)
                HStack {
                    Text(dayLabel(days.first!.date)).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(dayLabel(days.last!.date)).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }

    func isWeekend(_ date: Date) -> Bool {
        let w = Calendar.current.component(.weekday, from: date)
        return w == 1 || w == 7
    }

    func dayLabel(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: date)
        return String(format: "%d/%d", c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - 热力图

struct HeatGrid: View {
    let report: StatsReport

    var body: some View {
        var grid = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        for bucket in report.hours {
            grid[min(max(bucket.weekday - 1, 0), 6)][min(max(bucket.hour, 0), 23)] += bucket.duration
        }
        let maxValue = grid.flatMap { $0 }.max() ?? 1
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return VStack(alignment: .leading, spacing: 6) {
            Text("一周里的使用时段").font(.headline)
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 2) {
                    Text(names[row]).font(.system(size: 9)).foregroundStyle(.secondary)
                        .frame(width: 10)
                    ForEach(0..<24, id: \.self) { hour in
                        let ratio = maxValue > 0 ? grid[row][hour] / maxValue : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(ratio <= 0 ? 0.07 : 0.18 + ratio * 0.75))
                            .frame(height: 15)
                            .help("\(names[row]) \(hour):00　\(grid[row][hour] > 0 ? fmtDuration(grid[row][hour]) : "无")")
                    }
                }
            }
            HStack(spacing: 2) {
                Spacer().frame(width: 12)
                ForEach(0..<24, id: \.self) { hour in
                    Text(hour % 6 == 0 ? "\(hour)" : "").font(.system(size: 8))
                        .foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - 音量分布

struct VolumeBars: View {
    let report: StatsReport

    var body: some View {
        let bins = report.dbHistogram.filter { $0.duration > 0 }
        let maxValue = bins.map(\.duration).max() ?? 1
        VStack(alignment: .leading, spacing: 7) {
            Text("音量分布").font(.headline)
            if bins.isEmpty {
                Text("无音量数据").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(bins.indices, id: \.self) { i in
                    let bin = bins[i]
                    HStack(spacing: 8) {
                        Text("\(bin.label)").font(.system(size: 10).monospacedDigit())
                            .foregroundStyle(.secondary).frame(width: 38, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(bin.lower >= 80 ? Color.orange : Color.accentColor)
                                .frame(width: max(2, geo.size.width * bin.duration / maxValue))
                        }
                        .frame(height: 9)
                        Text(fmtDuration(bin.duration)).font(.system(size: 10).monospacedDigit())
                            .frame(width: 62, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 330, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - 会话表

struct SessionTable: View {
    let report: StatsReport

    var body: some View {
        let tops = report.sessions.sorted { $0.duration > $1.duration }.prefix(12)
        VStack(alignment: .leading, spacing: 8) {
            Text("最长的 \(tops.count) 次佩戴").font(.headline)
            VStack(spacing: 0) {
                HStack {
                    Text("时间").frame(maxWidth: .infinity, alignment: .leading)
                    Text("时长").frame(width: 80, alignment: .trailing)
                    Text("均音量").frame(width: 70, alignment: .trailing)
                    Text("峰值").frame(width: 60, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
                Divider()
                ForEach(Array(tops.enumerated()), id: \.offset) { _, session in
                    HStack {
                        Text(sessionLabel(session))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.callout)
                        Text(fmtDuration(session.duration))
                            .frame(width: 80, alignment: .trailing).monospacedDigit().font(.callout)
                        Text(session.avgDB.map { String(format: "%.0f dB", $0) } ?? "—")
                            .frame(width: 70, alignment: .trailing).monospacedDigit().font(.callout)
                        Text(session.maxDB.map { String(format: "%.0f", $0) } ?? "—")
                            .frame(width: 60, alignment: .trailing).monospacedDigit().font(.callout)
                            .foregroundStyle((session.maxDB ?? 0) >= 90 ? .orange : .primary)
                    }
                    .padding(.vertical, 5)
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
    }

    func sessionLabel(_ session: HeadphoneSession) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE HH:mm"
        let endFormatter = DateFormatter()
        endFormatter.locale = Locale(identifier: "zh_CN")
        endFormatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: session.start)) – \(endFormatter.string(from: session.end))"
    }
}

// MARK: - 工具

func fmtDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 { return "\(h) 小时 \(m) 分" }
    return "\(m) 分钟"
}
