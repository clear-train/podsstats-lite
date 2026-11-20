import Foundation

/// 生成单文件交互式 HTML 报告：数据内嵌，浏览器打开即用，可切换时间范围，不联网。
public enum HTMLReport {

    // MARK: - 数据结构

    private struct WebSession: Encodable {
        var s: Int          // 开始（epoch 秒）
        var e: Int          // 结束
        var db: Double      // 平均音量，0 表示未知
        var mx: Double      // 峰值音量，0 表示未知
        var loud: Int       // ≥80 dB 秒数
        var vl: Int         // ≥90 dB 秒数
        var src: String
        var d: Int          // 真实佩戴时长（秒，已去掉会话内断档）
        var n: Int          // 样本条数
        var b: [Int]        // 12 档音量分布（40 dB 起、5 dB 一档），单位秒
        var g: [[Int]]      // 实际有样本的连续区间 [[起, 止]]，epoch 秒
    }

    private struct WebMeta: Encodable {
        var file: String
        var generated: String
        var gap: Int
        var note: String
    }

    private struct WebPayload: Encodable {
        var meta: WebMeta
        var sessions: [WebSession]
    }

    // MARK: - 入口

    public static func render(report: StatsReport,
                              calendar: Calendar,
                              sourcePath: String,
                              timeZoneOffset: Int) -> String {
        let payload = WebPayload(
            meta: WebMeta(
                file: sourcePath,
                generated: HealthDate.format(Date(), timeZoneOffset: timeZoneOffset),
                gap: Int(report.optionsDescription["gap"].flatMap { Double($0) } ?? 300),
                note: "数据来自 Apple 健康「耳机音量」记录"
            ),
            sessions: report.sessions.map { session in
                WebSession(
                    s: Int(session.start.timeIntervalSince1970.rounded()),
                    e: Int(session.end.timeIntervalSince1970.rounded()),
                    db: session.avgDB ?? 0,
                    mx: session.maxDB ?? 0,
                    loud: Int(session.loudDuration.rounded()),
                    vl: Int(session.veryLoudDuration.rounded()),
                    src: session.source ?? "",
                    d: Int(session.duration.rounded()),
                    n: session.sampleCount,
                    b: session.dbBuckets.map { Int($0.rounded()) },
                    g: session.effectiveSpans.map { span in
                        [Int(span.start.timeIntervalSince1970.rounded()),
                         Int(span.end.timeIntervalSince1970.rounded())]
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        var json = "{\"meta\":{},\"sessions\":[]}"
        if let data = try? encoder.encode(payload), let text = String(data: data, encoding: .utf8) {
            // 防止提前闭合 script 标签
            json = text.replacingOccurrences(of: "</", with: "<\\/")
        }

        return template
            .replacingOccurrences(of: "__PAYLOAD__", with: json)
            .replacingOccurrences(of: "__BOOT__", with: "auto")
    }

    // MARK: - 模板

    /// 整页 = 静态结构（HTML/CSS）+ 脚本（统计与绘图）
    private static let template = HTMLReportMarkup.head + HTMLReportScript.script
}
