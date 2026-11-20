import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PodsStatsCore

@MainActor
final class AppModel: ObservableObject {

    enum State: Equatable {
        case empty
        case loading
        case failed(String)
        case ready
    }

    struct Meta {
        var fileName: String = ""
        var spanText: String = ""
        var sampleText: String = ""
    }

    @Published private(set) var state: State = .empty
    @Published private(set) var report: StatsReport?
    @Published private(set) var meta = Meta()
    @Published private(set) var isLoading = false
    @Published private(set) var statusText = ""

    private var loaded: HealthExportLoader.Loaded?

    // MARK: - 选文件

    func pickFile() {
        let panel = NSOpenPanel()
        panel.title = "选择 Apple 健康导出文件"
        panel.message = "选择 export.xml 或 iPhone 健康 App 导出的 export.zip"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        var types: [UTType] = []
        if let xml = UTType(filenameExtension: "xml") { types.append(xml) }
        if let zip = UTType(filenameExtension: "zip") { types.append(zip) }
        panel.allowedContentTypes = types.isEmpty ? [.data] : types
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(url: url)
    }

    // MARK: - 解析

    func load(url: URL) {
        state = .loading
        isLoading = true
        statusText = "正在解析 \(url.lastPathComponent)…"
        let started = Date()

        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let loaded = try HealthExportLoader.load(url: url)
                await MainActor.run {
                    self?.apply(loaded: loaded, startedAt: started)
                }
            } catch {
                await MainActor.run {
                    self?.isLoading = false
                    self?.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func apply(loaded: HealthExportLoader.Loaded, startedAt: Date) {
        self.loaded = loaded
        let samples = loaded.result.samples
        guard !samples.isEmpty else {
            isLoading = false
            state = .failed("""
            文件里没有耳机音频记录。
            请在 iPhone「健康 → 浏览 → 听觉 → 耳机音量」里确认有数据；\
            戴蓝牙或有线耳机播放过音频后系统才会记录。
            """)
            return
        }

        let sessions = SessionBuilder.build(from: samples)
        let report = StatsEngine.compute(
            sessions: sessions,
            samples: samples,
            calendar: .current,
            options: ["gap": "300"]
        )
        self.report = report

        let s = report.summary
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        let span: String
        if let first = s.firstDate, let last = s.lastDate {
            span = "\(formatter.string(from: first)) – \(formatter.string(from: last))，共 \(s.spanDays) 天"
        } else {
            span = "—"
        }
        let seconds = String(format: "%.2f", Date().timeIntervalSince(startedAt))
        meta = Meta(
            fileName: loaded.xmlURL.lastPathComponent,
            spanText: span,
            sampleText: "\(loaded.result.matchedRecords) 条耳机样本 → \(sessions.count) 次佩戴，解析耗时 \(seconds)s"
        )
        isLoading = false
        state = .ready
        HealthExportLoader.cleanup(loaded)
    }

    // MARK: - 导出 HTML

    func exportHTML() {
        guard let report else { return }
        let panel = NSSavePanel()
        panel.title = "导出 HTML 报告"
        panel.nameFieldStringValue = "耳机使用统计.html"
        if let html = UTType(filenameExtension: "html") { panel.allowedContentTypes = [html] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let html = HTMLReport.render(
            report: report,
            calendar: .current,
            sourcePath: meta.fileName,
            timeZoneOffset: TimeZone.current.secondsFromGMT()
        )
        do {
            try html.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            state = .failed("导出失败：\(error.localizedDescription)")
        }
    }
}
