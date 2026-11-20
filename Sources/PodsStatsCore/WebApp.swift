import Foundation

/// 生成网页版（GitHub Pages）：拖入 export.zip，全部在浏览器里解析，数据不出本机。
public enum WebApp {

    /// 返回完整的单文件 HTML。脚本顺序很重要：先用 BOOT=manual 让渲染引擎挂起并暴露
    /// `window.__podsstatsImport`，再接引导脚本接管文件读取。
    public static func html() -> String {
        let payload = #"{"meta":{"file":"","generated":"","gap":300,"note":""},"sessions":[]}"#
        return HTMLReportMarkup.head
            + HTMLReportScript.script
                .replacingOccurrences(of: "__PAYLOAD__", with: payload)
                .replacingOccurrences(of: "__BOOT__", with: "manual")
                .replacingOccurrences(of: "</body>", with: WebBootScript.script + "\n</body>")
    }

    /// 写盘便捷方法。
    @discardableResult
    public static func write(to path: String) throws -> Int {
        let html = html()
        try html.write(toFile: path, atomically: true, encoding: .utf8)
        return html.utf8.count
    }
}
