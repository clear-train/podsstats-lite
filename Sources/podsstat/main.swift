import Foundation
import PodsStatsCore

// MARK: - 参数

struct Args {
    var input: String?
    var gap: TimeInterval = 300
    var since: Date?
    var until: Date?
    var top: Int = 8
    var dailyLimit: Int = 14
    var jsonPath: String?
    var htmlPath: String?
    var csvPath: String?
    var mockPath: String?
    var mockDays: Int = 45
    var timeZoneOffset: Int = TimeZone.current.secondsFromGMT()
    var quiet = false
    var openReport = false
}

func printUsage() {
    let usage = """
    podsstat — 从 Apple 健康数据统计耳机使用情况

    用法:
      podsstat <export.xml | 导出的 zip>  [选项]
      podsstat --mock <输出路径>          [选项]    生成模拟数据用于试验

    选项:
      --gap <秒>       相邻样本间隔超过该值算两次佩戴，默认 300
      --since <日期>   只统计该日期之后，格式 2024-01-01
      --until <日期>   只统计该日期之前
      --top <n>       终端展示最长的 n 次佩戴，默认 8
      --daily <n>     终端展示最近 n 天，默认 14
      --json <路径>   导出完整统计 JSON
      --html <路径>   导出可视化 HTML 报告
      --web <路径>    导出「网页版」：拖入 zip 就地解析，可托管到 GitHub Pages
      --csv <路径>    导出会话明细 CSV
      --tz <+08:00>   统计时区，默认跟随系统
      --days <n>      配合 --mock，生成 n 天数据，默认 45
      --open          生成 HTML 报告后直接用浏览器打开（未给 --html 时写到临时文件）
      --quiet         只输出结论，不输出明细
      -h, --help      显示帮助

    数据来源:
      iPhone 健康 App → 头像 → 导出所有健康数据 → 得到 export.zip
      （解压后是 apple_health_export/export.xml，本工具两者都能直接读）
    """
    print(usage)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("[错误] " + message + "\n").data(using: .utf8)!)
    exit(1)
}

// MARK: - 参数解析

var args = Args()
var iterator = CommandLine.arguments.dropFirst().makeIterator()

func parseDateArg(_ raw: String) -> Date? {
    let parts = raw.split(separator: "-")
    guard parts.count == 3,
          let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
    var comps = DateComponents()
    comps.year = y; comps.month = m; comps.day = d
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: args.timeZoneOffset) ?? .current
    return calendar.date(from: comps)
}

while let arg = iterator.next() {
    switch arg {
    case "-h", "--help":
        printUsage(); exit(0)
    case "--gap":
        guard let v = iterator.next(), let n = Double(v) else { fail("--gap 需要一个数字") }
        args.gap = n
    case "--since":
        guard let v = iterator.next(), let d = parseDateArg(v) else { fail("--since 格式应为 2024-01-01") }
        args.since = d
    case "--until":
        guard let v = iterator.next(), let d = parseDateArg(v) else { fail("--until 格式应为 2024-01-01") }
        args.until = d
    case "--top":
        guard let v = iterator.next(), let n = Int(v) else { fail("--top 需要一个整数") }
        args.top = n
    case "--daily":
        guard let v = iterator.next(), let n = Int(v) else { fail("--daily 需要一个整数") }
        args.dailyLimit = n
    case "--json":
        args.jsonPath = iterator.next()
    case "--html":
        args.htmlPath = iterator.next()
    case "--web":
        if let p = iterator.next() {
            let n = try? WebApp.write(to: p)
            print("已写出网页版：\(p)（\(n ?? 0) 字节）")
            print("托管到 GitHub Pages 后，任何人打开即可拖入自己的 export.zip；数据只在浏览器里解析。")
            exit(0)
        }
    case "--csv":
        args.csvPath = iterator.next()
    case "--mock":
        args.mockPath = iterator.next()
    case "--days":
        guard let v = iterator.next(), let n = Int(v) else { fail("--days 需要一个整数") }
        args.mockDays = n
    case "--tz":
        guard let v = iterator.next() else { fail("--tz 需要值，如 +08:00") }
        let sign: Int = v.hasPrefix("-") ? -1 : 1
        let body = v.hasPrefix("+") || v.hasPrefix("-") ? String(v.dropFirst()) : v
        let parts = body.split(separator: ":")
        if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
            args.timeZoneOffset = sign * (h * 3600 + m * 60)
        } else if let h = Int(body) {
            args.timeZoneOffset = sign * h * 3600
        } else {
            fail("--tz 格式应为 +08:00")
        }
    case "--open":
        args.openReport = true
    case "--quiet":
        args.quiet = true
    default:
        if arg.hasPrefix("--") { fail("未知选项 \(arg)") }
        args.input = arg
    }
}

// MARK: - mock 生成

if let mockPath = args.mockPath {
    var config = MockExport.Config()
    config.days = args.mockDays
    config.timeZoneOffset = args.timeZoneOffset
    do {
        try MockExport.write(to: URL(fileURLWithPath: mockPath), config: config)
        print("已生成模拟数据：\(mockPath)（\(args.mockDays) 天）")
        print("试跑：./podsstat \(mockPath)")
        exit(0)
    } catch {
        fail("生成失败：\(error.localizedDescription)")
    }
}

// MARK: - 定位 export.xml

guard let inputPath = args.input else {
    printUsage()
    exit(1)
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: args.timeZoneOffset) ?? .current

let fm = FileManager.default
var xmlURL: URL?
var temporaryDir: URL?

if inputPath.lowercased().hasSuffix(".zip") {
    let tmp = fm.temporaryDirectory.appendingPathComponent("podsstat-\(UUID().uuidString)")
    try? fm.createDirectory(at: tmp, withIntermediateDirectories: true)
    temporaryDir = tmp
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-o", "-q", inputPath, "-d", tmp.path]
    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fail("解压失败：\(error.localizedDescription)")
    }
    if process.terminationStatus != 0 {
        fail("解压失败，请确认 zip 是否完整（也可手动解压后直接指向 export.xml）")
    }
    let enumerator = fm.enumerator(at: tmp, includingPropertiesForKeys: nil)
    while let url = enumerator?.nextObject() as? URL {
        if url.lastPathComponent == "export.xml" { xmlURL = url; break }
    }
} else {
    xmlURL = URL(fileURLWithPath: (inputPath as NSString).expandingTildeInPath)
}

guard let url = xmlURL, fm.fileExists(atPath: url.path) else {
    fail("找不到导出文件：\(inputPath)")
}

let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
if !args.quiet {
    print("读取 \(url.path)（\(String(format: "%.1f", Double(size) / 1_048_576)) MB）…")
}

// MARK: - 解析

let startTime = Date()
let parser: HealthExportParser
do {
    parser = try HealthExportParser(url: url)
} catch {
    fail(error.localizedDescription)
}

let parsed: HealthExportParser.Result
do {
    parsed = try parser.parse()
} catch {
    fail("""
    \(error.localizedDescription)
    文件可能不完整（导出或传输过程被中断），也可能不是 Apple 健康的 export.xml。
    可以用 `unzip -t 你的文件.zip` 先验证压缩包完整性，再重新从健康 App 导出。
    """)
}

if let temp = temporaryDir { try? fm.removeItem(at: temp) }

guard !parsed.samples.isEmpty else {
    let histo = parsed.typeHistogram.isEmpty
        ? "文件中没有任何耳机音频记录"
        : "文件里的相关类型：" + parsed.typeHistogram.map { "\($0.key) × \($0.value)" }.joined(separator: "，")
    fail("""
    没有找到耳机音频数据。
    排查建议：
      1. 确认手机上有过「戴耳机听音频」的记录（健康 App → 浏览 → 听觉 → 耳机音量）
      2. 确认导出的是「所有健康数据」而不是某个单项
      3. 该功能需要 iOS 13+ 且耳机为蓝牙/有线耳机，数据由 iPhone 自动记录
    \(histo)
    """)
}

// MARK: - 过滤

var samples = parsed.samples
if let since = args.since { samples = samples.filter { $0.start >= since } }
if let until = args.until { samples = samples.filter { $0.start <= until } }

guard !samples.isEmpty else { fail("指定时间范围内没有数据") }

// MARK: - 汇总

let sessions = SessionBuilder.build(from: samples, options: .init(gap: args.gap))
guard !sessions.isEmpty else { fail("样本太少，无法切分出使用会话") }

var optionsDesc: [String: String] = ["gap": String(Int(args.gap))]
if let since = args.since { optionsDesc["since"] = HealthDate.format(since, timeZoneOffset: args.timeZoneOffset) }
if let until = args.until { optionsDesc["until"] = HealthDate.format(until, timeZoneOffset: args.timeZoneOffset) }
let report = StatsEngine.compute(sessions: sessions, samples: samples, calendar: calendar, options: optionsDesc)

if args.quiet {
    for line in InsightGenerator.generate(report: report, calendar: calendar) {
        print("· " + line)
    }
} else {
    print(TextReport.render(report: report, calendar: calendar,
                            dailyLimit: args.dailyLimit, topLimit: args.top))
    let elapsed = Date().timeIntervalSince(startTime)
    print("  解析 \(parsed.scannedRecords) 条记录，命中 \(parsed.matchedRecords) 条耳机样本，"
          + "切成 \(sessions.count) 次佩戴，耗时 \(String(format: "%.2f", elapsed))s")
    print("")
}

// MARK: - 导出

let isoFormatter = ISO8601DateFormatter()

if let jsonPath = args.jsonPath {
    var payload: [String: Any] = [:]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    if let data = try? encoder.encode(report) {
        try? data.write(to: URL(fileURLWithPath: jsonPath))
        payload["ok"] = true
    }
    if payload["ok"] != nil {
        print("已写出 JSON：\(jsonPath)")
    } else {
        fail("JSON 导出失败")
    }
}

if let csvPath = args.csvPath {
    let localFormatter = DateFormatter()
    localFormatter.locale = Locale(identifier: "en_US_POSIX")
    localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    localFormatter.timeZone = TimeZone(secondsFromGMT: args.timeZoneOffset)
    var csv = "start_local,end_local,start_utc,end_utc,duration_seconds,minutes,samples,avg_db,max_db,over_80db_seconds,over_90db_seconds,source\n"
    for s in report.sessions {
        csv += [
            localFormatter.string(from: s.start),
            localFormatter.string(from: s.end),
            isoFormatter.string(from: s.start),
            isoFormatter.string(from: s.end),
            String(format: "%.0f", s.duration),
            String(format: "%.1f", s.minutes),
            "\(s.sampleCount)",
            s.avgDB.map { String(format: "%.1f", $0) } ?? "",
            s.maxDB.map { String(format: "%.1f", $0) } ?? "",
            String(format: "%.0f", s.loudDuration),
            String(format: "%.0f", s.veryLoudDuration),
            (s.source ?? "").replacingOccurrences(of: ",", with: " ")
        ].joined(separator: ",") + "\n"
    }
    try? csv.write(toFile: csvPath, atomically: true, encoding: .utf8)
    print("已写出 CSV：\(csvPath)")
}

let defaultReportPath = NSTemporaryDirectory() + "podsstat-report.html"
if let htmlPath = args.htmlPath ?? (args.openReport ? defaultReportPath : nil) {
    let html = HTMLReport.render(report: report, calendar: calendar,
                                 sourcePath: url.lastPathComponent,
                                 timeZoneOffset: args.timeZoneOffset)
    do {
        try html.write(toFile: htmlPath, atomically: true, encoding: .utf8)
        print("已写出 HTML 报告：\(htmlPath)")
        if args.openReport {
            let open = Process()
            open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            open.arguments = [htmlPath]
            try? open.run()
        } else {
            print("打开：open \"\(htmlPath)\"")
        }
    } catch {
        fail("HTML 写出失败：\(error.localizedDescription)")
    }
}
