import SwiftUI
import Charts
import PodsStatsCore

struct DashboardView: View {
    @StateObject private var health = HeadphoneHealthStore()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                switch health.state {
                case .idle:
                    WelcomeView { Task { await health.requestAuthorizationAndLoad() } }
                case .requesting, .loading:
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("正在读取耳机数据…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .denied:
                    DeniedView {
                        Task { await health.requestAuthorizationAndLoad() }
                    }
                case .failed(let message):
                    ContentUnavailableViewCompat(title: "读取失败", message: message)
                case .ready:
                    content
                }
            }
            .navigationTitle("耳机使用")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(health: health)
            }
        }
        .task {
            if health.state == .idle, health.isHealthDataAvailable {
                await health.requestAuthorizationAndLoad()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let report = health.report, !health.sessions.isEmpty {
            ScrollView {
                VStack(spacing: 20) {
                    metricGrid(report)
                    DailyChartCard(report: report)
                    HourHeatCard(report: report)
                    VolumeCard(report: report)
                    SessionListCard(report: report)
                    Text("共 \(health.sampleCount) 条原始样本，切成 \(health.sessions.count) 次佩戴")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable { await health.load() }
        } else {
            ContentUnavailableViewCompat(
                title: "还没有耳机音量数据",
                message: "在健康 App 里确认有「听觉 → 耳机音量」记录。需要戴蓝牙/有线耳机播放过音频，系统才会自动记录。"
            )
        }
    }

    private func metricGrid(_ report: StatsReport) -> some View {
        let s = report.summary
        let items: [(String, String, String)] = [
            ("累计佩戴", fmtDuration(s.totalDuration), "近 \(health.rangeDays) 天"),
            ("佩戴次数", "\(s.sessionCount)", "平均 \(fmtDuration(s.averageSession))"),
            ("使用天数", "\(s.activeDays)", "连续 \(s.currentStreak) 天"),
            ("活跃日日均", fmtDuration(s.averageActiveDay), "最长单次 \(fmtDuration(s.longestSession))"),
            ("平均音量", s.averageDB.map { String(format: "%.0f dB", $0) } ?? "—",
             "峰值 \(s.peakDB.map { String(format: "%.0f", $0) } ?? "—") dB"),
            ("≥80dB 时长", fmtDuration(s.loudDuration),
             String(format: "占 %.0f%%", s.totalDuration > 0 ? s.loudDuration / s.totalDuration * 100 : 0))
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Text(items[i].0).font(.caption).foregroundStyle(.secondary)
                    Text(items[i].1).font(.title3.weight(.semibold)).monospacedDigit()
                    Text(items[i].2).font(.caption2).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

// MARK: - 图表

struct DailyChartCard: View {
    let report: StatsReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每日佩戴时长").font(.headline)
            let days = Array(report.days.suffix(30))
            if days.isEmpty {
                Text("无数据").font(.footnote).foregroundStyle(.secondary)
            } else {
                Chart(days) { day in
                    BarMark(
                        x: .value("日期", day.date, unit: .day),
                        y: .value("分钟", day.minutes)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.85))
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let minutes = value.as(Double.self) {
                                Text("\(Int(minutes / 60))h")
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct HourHeatCard: View {
    let report: StatsReport

    private var matrix: [[Double]] {
        var grid = Array(repeating: Array(repeating: 0.0, count: 24), count: 7)
        for bucket in report.hours {
            let row = min(max(bucket.weekday - 1, 0), 6)
            let hour = min(max(bucket.hour, 0), 23)
            grid[row][hour] += bucket.duration
        }
        return grid
    }

    var body: some View {
        let grid = matrix
        let maxValue = grid.flatMap { $0 }.max() ?? 0
        VStack(alignment: .leading, spacing: 8) {
            Text("一周里的使用时段").font(.headline)
            Text("颜色越深表示该时段累计越久").font(.caption2).foregroundStyle(.secondary)
            let names = ["日", "一", "二", "三", "四", "五", "六"]
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 2) {
                    Text(names[row])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    ForEach(0..<24, id: \.self) { hour in
                        let value = grid[row][hour]
                        let ratio = maxValue > 0 ? value / maxValue : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(ratio <= 0 ? 0.06 : 0.15 + ratio * 0.8))
                            .frame(height: 16)
                    }
                }
            }
            HStack(spacing: 2) {
                Spacer().frame(width: 14)
                ForEach(0..<24, id: \.self) { hour in
                    Text(hour % 6 == 0 ? "\(hour)" : "")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct VolumeCard: View {
    let report: StatsReport

    var body: some View {
        let bins = report.dbHistogram.filter { $0.duration > 0 }
        let maxValue = bins.map(\.duration).max() ?? 1
        VStack(alignment: .leading, spacing: 10) {
            Text("音量分布").font(.headline)
            if bins.isEmpty {
                Text("无音量数据").font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(bins.indices, id: \.self) { i in
                    let bin = bins[i]
                    HStack(spacing: 10) {
                        Text("\(bin.label) dB")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 62, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(bin.lower >= 80 ? Color.orange : Color.accentColor)
                                .frame(width: max(2, geo.size.width * bin.duration / maxValue))
                        }
                        .frame(height: 8)
                        Text(fmtDuration(bin.duration))
                            .font(.caption2)
                            .monospacedDigit()
                            .frame(width: 54, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SessionListCard: View {
    let report: StatsReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近的佩戴记录").font(.headline)
            let recent = report.sessions.sorted { $0.start > $1.start }.prefix(20)
            ForEach(Array(recent.enumerated()), id: \.offset) { _, session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.start.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                        Text("\(session.avgDB.map { String(format: "均 %.0f dB", $0) } ?? "—") · 峰值 \(session.maxDB.map { String(format: "%.0f", $0) } ?? "—")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(fmtDuration(session.duration))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle((session.maxDB ?? 0) >= 90 ? .orange : .primary)
                }
                .padding(.vertical, 6)
                if session.start != recent.last?.start {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 引导页

struct WelcomeView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "airpodspro")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("用你的健康数据统计耳机使用").font(.title2.weight(.semibold))
            Text("读取 Apple 健康里的「耳机音量」记录，算出戴耳机听了多久、音量多高。只读，不上传。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text("连接健康数据").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
    }
}

struct DeniedView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("没有拿到耳机数据的权限").font(.headline)
            Text("设置 → 健康 → 数据访问与设备 → 本应用 → 打开「耳机音量」读取权限")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重新检查", action: retry).buttonStyle(.bordered)
        }
        .padding(28)
    }
}

struct ContentUnavailableViewCompat: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.slash").font(.system(size: 44)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        .padding(28)
    }
}

struct SettingsSheet: View {
    @ObservedObject var health: HeadphoneHealthStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("统计范围") {
                    Picker("天数", selection: $health.rangeDays) {
                        Text("30 天").tag(30)
                        Text("90 天").tag(90)
                        Text("180 天").tag(180)
                        Text("一年").tag(365)
                    }
                }
                Section("会话切分") {
                    Stepper("间隔 \(health.gapMinutes) 分钟", value: $health.gapMinutes, in: 1...30)
                    Text("两段聆听之间停顿超过这个时长，就算作两次佩戴。默认 5 分钟。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("重新读取") {
                        dismiss()
                        Task { await health.load() }
                    }
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 工具

func fmtDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)m"
}
