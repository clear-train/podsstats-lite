import Foundation

/// 统一入口：给一个 export.xml 或 Apple 导出的 zip，返回解析结果
public enum HealthExportLoader {

    public struct Loaded {
        public var xmlURL: URL
        public var result: HealthExportParser.Result
        public var fileSizeBytes: Int64
        public var temporaryDirectory: URL?
    }

    /// 若传入 zip，自动解压到临时目录并找到 export.xml
    public static func resolveXML(from url: URL) throws -> (xmlURL: URL, tempDir: URL?) {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw PodsStatsError.cannotOpen(url.path)
        }

        let lowercase = url.lastPathComponent.lowercased()
        if lowercase.hasSuffix(".zip") {
            let temp = fm.temporaryDirectory.appendingPathComponent("podsstat-\(UUID().uuidString)")
            try fm.createDirectory(at: temp, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", "-q", url.path, "-d", temp.path]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw PodsStatsError.parseFailed("解压失败，请确认 zip 完整")
            }
            var found: URL?
            if let enumerator = fm.enumerator(at: temp, includingPropertiesForKeys: nil) {
                while let child = enumerator.nextObject() as? URL {
                    if child.lastPathComponent == "export.xml" { found = child; break }
                }
            }
            guard let xml = found else {
                throw PodsStatsError.noData("zip 里没有找到 export.xml，请确认导出的是「所有健康数据」")
            }
            return (xml, temp)
        }
        return (url, nil)
    }

    public static func load(url: URL, includeEnvironmental: Bool = false) throws -> Loaded {
        let (xmlURL, temp) = try resolveXML(from: url)
        let size = (try? FileManager.default.attributesOfItem(atPath: xmlURL.path)[.size] as? Int64) ?? 0
        let parser = try HealthExportParser(url: xmlURL, includeEnvironmental: includeEnvironmental)
        let result = try parser.parse()
        return Loaded(xmlURL: xmlURL, result: result, fileSizeBytes: size, temporaryDirectory: temp)
    }

    public static func cleanup(_ loaded: Loaded) {
        if let temp = loaded.temporaryDirectory {
            try? FileManager.default.removeItem(at: temp)
        }
    }
}
