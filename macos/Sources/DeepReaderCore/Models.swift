// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum Provider: String, Codable, CaseIterable, Identifiable {
    case deepSeek = "DeepSeek"
    case openAI = "OpenAI"
    case claude = "Claude"
    case gemini = "Gemini"
    case qwen = "Qwen"
    case kimi = "Kimi"
    case glm = "GLM"
    case doubao = "Doubao"
    case miniMax = "MiniMax"
    case grok = "Grok"
    case mistral = "Mistral"
    case openRouter = "OpenRouter"
    case custom = "Custom"
    public var id: String { rawValue }
    public static var isAppStoreBuild: Bool {
        Bundle.main.object(forInfoDictionaryKey: "DeepReaderAppStoreBuild") as? Bool == true
    }
    public static func available(appStore: Bool = isAppStoreBuild) -> [Self] { allCases }
    public var endpoint: URL {
        switch self {
        case .deepSeek: return URL(string: "https://api.deepseek.com/chat/completions")!
        case .openAI: return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .claude: return URL(string: "https://api.anthropic.com/v1/messages")!
        case .gemini: return URL(string: "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")!
        case .qwen: return URL(string: "https://dashscope-us.aliyuncs.com/compatible-mode/v1/chat/completions")!
        case .kimi: return URL(string: "https://api.moonshot.ai/v1/chat/completions")!
        case .glm: return URL(string: "https://api.z.ai/api/paas/v4/chat/completions")!
        case .doubao: return URL(string: "https://ark.cn-beijing.volces.com/api/v3/chat/completions")!
        case .miniMax: return URL(string: "https://api.minimax.io/v1/chat/completions")!
        case .grok: return URL(string: "https://api.x.ai/v1/chat/completions")!
        case .mistral: return URL(string: "https://api.mistral.ai/v1/chat/completions")!
        case .openRouter: return URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        case .custom: return URL(string: "https://example.invalid/v1/chat/completions")!
        }
    }
    public var models: [String] {
        switch self {
        case .deepSeek: return ["deepseek-flash", "deepseek-v4-pro"]
        case .openAI: return ["gpt-4.1-mini"]
        case .claude: return ["claude-sonnet-5-5", "claude-haiku-5-5"]
        case .gemini: return ["gemini-3.8-flash"]
        case .qwen: return ["qwen-plus"]
        case .kimi: return ["kimi-k2.6"]
        case .glm: return ["glm-4.7"]
        case .doubao: return []
        case .miniMax: return ["MiniMax-M3", "MiniMax-M3.1-Flash-Preview"]
        case .grok: return ["grok-4.7"]
        case .mistral: return ["mistral-small-latest"]
        case .openRouter: return ["openrouter/free"]
        case .custom: return []
        }
    }
    public var keyURL: URL {
        switch self {
        case .deepSeek: return URL(string: "https://platform.deepseek.com/api_keys")!
        case .openAI: return URL(string: "https://platform.openai.com/api-keys")!
        case .claude: return URL(string: "https://platform.claude.com/settings/keys")!
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")!
        case .qwen: return URL(string: "https://modelstudio.console.alibabacloud.com/")!
        case .kimi: return URL(string: "https://platform.kimi.ai/console/api-keys")!
        case .glm: return URL(string: "https://z.ai/manage-apikey/apikey-list")!
        case .doubao: return URL(string: "https://console.volcengine.com/ark/")!
        case .miniMax: return URL(string: "https://platform.minimax.io/")!
        case .grok: return URL(string: "https://console.x.ai/")!
        case .mistral: return URL(string: "https://console.mistral.ai/")!
        case .openRouter: return URL(string: "https://openrouter.ai/settings/keys")!
        case .custom: return URL(string: "https://github.com/BaoshiSun/DeepReader")!
        }
    }
    public var requiresAdultConfirmation: Bool { self == .gemini || self == .openRouter }
    public var termsURL: URL? {
        if self == .gemini { return URL(string: "https://ai.google.dev/gemini-api/terms") }
        if self == .openRouter { return URL(string: "https://openrouter.ai/terms") }
        return nil
    }
}

public struct Settings: Codable {
    public var provider: Provider = .deepSeek
    public var english = false
    public var onboardingSeen = false
    public var models: [String: String] = [:]
    // Optional additions preserve decoding of libraries written by older releases.
    public var endpoints: [String: String]?
    public var adultConfirmed: Bool?
    // Optional for libraries saved before knowledge-scope selection.
    public var useWorldKnowledge: Bool?
    public var aiSharingConsentRecipient: String?
    public var aiSharingConsentVersion: Int?
    public var knowledgeInstruction: String {
        if useWorldKnowledge == true {
            return " Knowledge scope: GENERAL_KNOWLEDGE. Actively use relevant established general knowledge to answer the current question, even when that information is absent from the supplied passages. Do not stop at saying the source lacks details when you can give a useful general explanation. This current mode overrides the scope of previous answers; reassess the question instead of repeating an earlier source-only refusal. For quantitative questions, distinguish the unknown measurement for this specific case from general mechanisms, calculation methods and conditional examples. Give a typical range only when you reliably know one for the same method and conditions, with units and assumptions. Otherwise give a clearly labeled hypothetical calculation or useful comparison and ask a focused clarification about the missing method or conditions. Never fabricate a precise value or universal range. Clearly distinguish source-supported statements from additional background or examples, labeling the latter as general knowledge in the response language. Do not attribute outside knowledge to the author. Summaries must faithfully summarize the source; keep any additional background separate, including in intermediate notes. State uncertainty; do not invent citations or claim web browsing, live verification or current information."
        }
        return " Knowledge scope: SOURCE_ONLY. Use the supplied source passages as the sole factual evidence. Language understanding is allowed, but do not add outside facts, background or examples. Previous AI answers and their general-knowledge additions are not source evidence. If the source does not answer the question, explicitly say the supplied text is insufficient. Do not invent missing facts."
    }
    public var archiveFolder = ""
    public var sidebarWidth: Double = 420
    public var floating = false
    public var floatingWidth: Double = 460
    public var floatingHeight: Double = 760
    public var lookupSplit: Double = 0.5
    public init() {}
    public var model: String { models[provider.rawValue] ?? provider.models.first ?? "" }
    public var endpointText: String { endpoints?[provider.rawValue] ?? (provider == .custom ? "" : provider.endpoint.absoluteString) }
    public mutating func setEndpoint(_ value: String) {
        var values = endpoints ?? [:]
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == provider.endpoint.absoluteString { values.removeValue(forKey: provider.rawValue) }
        else { values[provider.rawValue] = trimmed }
        endpoints = values
    }
    public var recipientID: String { provider.rawValue + "|" + endpointText }
    public func requestEndpoint() throws -> URL {
        guard Self.validEndpoint(endpointText), let url = URL(string: endpointText) else {
            throw ReaderError("请输入完整的 HTTPS 接口地址，不能包含账号、查询参数或片段。", "Enter a full HTTPS endpoint without credentials, query or fragment.")
        }
        return url
    }
    public static func validEndpoint(_ text: String) -> Bool {
        guard text.utf8.count <= 2048, !text.contains(where: { $0.isWhitespace }),
              let parts = URLComponents(string: text), parts.scheme == "https",
              let host = parts.host, !host.isEmpty, host != "example.invalid",
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              !parts.path.isEmpty, parts.path != "/" else { return false }
        return parts.url != nil
    }
    public var freeModel: Bool { provider == .openRouter && (model == "openrouter/free" || model.hasSuffix(":free")) }
    public func validated() throws -> Self {
        guard models.values.allSatisfy(Self.validModel), (endpoints ?? [:]).values.allSatisfy(Self.validEndpoint), archiveFolder.utf8.count <= 16384,
              sidebarWidth.isFinite, floatingWidth.isFinite, floatingHeight.isFinite, lookupSplit.isFinite else {
            throw ReaderError("设置无效。", "Invalid settings.")
        }
        var copy = self
        copy.sidebarWidth = min(1000, max(360, sidebarWidth))
        copy.floatingWidth = min(1400, max(380, floatingWidth))
        copy.floatingHeight = min(1400, max(520, floatingHeight))
        copy.lookupSplit = min(0.8, max(0.2, lookupSplit))
        return copy
    }
    public static func validModel(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 160 && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_/.: ").subtracting(.whitespaces).contains($0)
        }
    }
    public static func validKey(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 512 && value.utf8.allSatisfy { $0 >= 33 && $0 <= 126 }
    }
}

public struct ReaderError: Error, LocalizedError {
    public let chinese: String
    public let english: String
    public init(_ chinese: String, _ english: String) { self.chinese = chinese; self.english = english }
    public func message(_ en: Bool) -> String { en ? english : chinese }
    public var errorDescription: String? { english }
}

public enum Dates {
    public static func stamp(_ date: Date = Date()) -> String {
        let f = ISO8601DateFormatter(); f.timeZone = .current
        return f.string(from: date)
    }
    public static func day(_ date: Date = Date()) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }
    public static func parse(_ string: String) -> Date? {
        guard string.count == 10 else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard let date = f.date(from: string), f.string(from: date) == string else { return nil }
        return date
    }
    public static func range(scope: Int, anchor: String) -> ClosedRange<String>? {
        guard let date = parse(anchor), (1...3).contains(scope) else { return nil }
        var cal = Calendar(identifier: .gregorian); cal.firstWeekday = 2
        if scope == 1 { return anchor...anchor }
        if scope == 2 {
            let weekday = cal.component(.weekday, from: date)
            guard let start = cal.date(byAdding: .day, value: -((weekday + 5) % 7), to: date),
                  let end = cal.date(byAdding: .day, value: 6, to: start) else { return nil }
            return day(start)...day(end)
        }
        guard let interval = cal.dateInterval(of: .month, for: date),
              let end = cal.date(byAdding: .day, value: -1, to: interval.end) else { return nil }
        return day(interval.start)...day(end)
    }
}

public struct ReadingRecord: Codable, Identifiable {
    public var id = UUID().uuidString.lowercased()
    public var time = Dates.stamp()
    public var file = ""
    public var title = ""
    public var selected = ""
    public var context = ""
    public var answer = ""
    public var kind = "explain"
    public var provider = ""
    public var model = ""
    public var language = "zh"
    public var page = 0
    public init() {}
    public var valid: Bool {
        UUID(uuidString: id) != nil && Dates.parse(String(time.prefix(10))) != nil &&
        ["explain", "file", "day", "week", "month"].contains(kind) &&
        file.utf8.count <= 32768 && title.utf16.count <= 1024 && selected.utf16.count <= 4000 &&
        context.utf16.count <= 5000 && !answer.isEmpty && answer.utf16.count <= 20000 &&
        provider.utf8.count < 64 && model.utf8.count < 200 && ["zh", "en"].contains(language) && page >= 0
    }
    public func matches(_ search: String) -> Bool {
        (title + " " + URL(fileURLWithPath: file).lastPathComponent + " " + selected + " " + answer + " " + time)
            .localizedCaseInsensitiveContains(search) || search.isEmpty
    }
    public func text(english: Bool) -> String {
        "\(time) · \(provider) / \(model)\n\(title)\n\(URL(fileURLWithPath: file).lastPathComponent)" +
        (page > 0 ? " · \(english ? "Page" : "页") \(page)" : "") + "\n\n\(selected)\n\n\(answer)" +
        (context.isEmpty ? "" : "\n\n\(english ? "Source context" : "原始语境")\n\(context)")
    }
}

public struct Book: Codable, Identifiable {
    public var id = UUID().uuidString.lowercased()
    public var file: String
    public var title: String
    public var added = Dates.stamp()
    public var updated = Dates.stamp()
    public var finishedAt = ""
    public var archivePath = ""
    public var copies: [String] = []
    public var rating = 0
    public var finished = false
    public init(file: URL) { self.file = file.standardizedFileURL.path; title = file.lastPathComponent }
    public var valid: Bool {
        UUID(uuidString: id) != nil && file.hasPrefix("/") && !title.isEmpty && title.utf16.count <= 1024 &&
        (0...5).contains(rating) && Dates.parse(String(added.prefix(10))) != nil &&
        Dates.parse(String(updated.prefix(10))) != nil && (finished ? Dates.parse(String(finishedAt.prefix(10))) != nil : finishedAt.isEmpty) &&
        (archivePath.isEmpty || archivePath.hasPrefix("/")) && copies.count <= 1000 && copies.allSatisfy { $0.hasPrefix("/") }
    }
    public func hasPath(_ path: String) -> Bool {
        guard path.hasPrefix("/") else { return false }
        let normalized = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
        return ([file, archivePath] + copies).filter { !$0.isEmpty }.contains {
            URL(fileURLWithPath: $0).standardizedFileURL.resolvingSymlinksInPath().path == normalized
        }
    }
    public mutating func setFinished(_ value: Bool) {
        if value && !finished { finishedAt = Dates.stamp() }
        if !value { finishedAt = "" }
        finished = value
    }
    public func matches(_ query: String, filter: Int) -> Bool {
        !(filter == 1 && finished) && !(filter == 2 && !finished) &&
        (query.isEmpty || (title + " " + file + " " + finishedAt).localizedCaseInsensitiveContains(query))
    }
    public func text(records: [ReadingRecord], english en: Bool) -> String {
        let stars = rating == 0 ? (en ? "Unrated" : "未评分") : String(repeating: "★", count: rating) + String(repeating: "☆", count: 5-rating)
        let summary = records.filter { $0.kind == "file" && hasPath($0.file) }.max { $0.time < $1.time }
        return "\(title)\n\(stars) · \(finished ? (en ? "Finished" : "读完") : (en ? "Reading" : "阅读中"))\n" +
            "\(en ? "Added" : "加入书单")：\(added.prefix(10))" +
            (finished ? "\n\(en ? "Completed" : "完成日期")：\(finishedAt.prefix(10))" : "") +
            "\n\(en ? "Original" : "原文件")：\(file)" + (archivePath.isEmpty ? "" : "\n\(en ? "Archived copy" : "归档副本")：\(archivePath)") +
            "\n\n\(en ? "Saved AI summary" : "已保存的 AI 总结")\n" +
            (summary?.answer ?? (en ? "No document summary yet. Generate one in Summary." : "暂无全文总结，可在“总结”页生成。"))
    }
    public static func overview(_ books: [Book], english en: Bool) -> String {
        let finished = books.filter(\.finished).count, rated = books.filter { $0.rating > 0 }
        let average = rated.isEmpty ? "—" : String(format: "%.1f", Double(rated.reduce(0) { $0 + $1.rating }) / Double(rated.count))
        return en ? "Books: \(books.count) · Reading: \(books.count-finished) · Finished: \(finished)\nRated: \(rated.count) · Average: \(average) / 5" :
            "书单 \(books.count) 本 · 阅读中 \(books.count-finished) 本 · 读完 \(finished) 本\n已评分 \(rated.count) 本 · 平均 \(average) / 5 星"
    }
}

public struct ReadingStats {
    public let lookups: Int, distinct: Int, files: Int, summaries: Int, days: Int
    public init(_ records: [ReadingRecord], range: ClosedRange<String>? = nil, book: Book? = nil) {
        let selected = records.filter {
            ["explain", "file"].contains($0.kind) && (range == nil || range!.contains(String($0.time.prefix(10)))) &&
            (book == nil || book!.hasPath($0.file))
        }
        let queries = selected.filter { $0.kind == "explain" }
        lookups = queries.count
        distinct = Set(queries.map { $0.selected.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }).count
        files = Set(selected.map(\.file).filter { !$0.isEmpty }).count
        summaries = selected.filter { $0.kind == "file" }.count
        days = Set(selected.map { String($0.time.prefix(10)) }).count
    }
    public func text(total: Int, english: Bool) -> String {
        english ? "All-time successful lookups: \(total)\nIn this scope: \(lookups) lookups · \(distinct) distinct selections\nRepeat lookups: \(lookups-distinct) · Documents: \(files)\nFile summaries: \(summaries) · Active days: \(days)\nBased on saved records; failed requests are excluded." :
        "累计成功查询：\(total) 次\n本范围：查询 \(lookups) 次 · 不同词句 \(distinct) 个\n重复查询：\(lookups-distinct) 次 · 涉及文件：\(files) 份\n文件总结：\(summaries) 次 · 活跃日期：\(days) 天\n按已保存记录统计，不含失败请求。"
    }
}
