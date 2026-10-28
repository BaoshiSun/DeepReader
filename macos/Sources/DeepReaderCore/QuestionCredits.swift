// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import StoreKit
import SwiftUI

public enum OrdinaryQuestions {
    public static let productID = "org.deepreader.questions.500"
    public static let packSize = 500
    public static let maximumSourceBytes = 6000
    public static var enabled: Bool { Provider.isAppStoreBuild }
    public static var recipient: String {
        "DeepReader + DeepSeek|" + (Bundle.main.object(forInfoDictionaryKey: "DeepReaderGatewayURL") as? String ?? "") + "|" +
        (Bundle.main.object(forInfoDictionaryKey: "DeepReaderSandboxGatewayURL") as? String ?? "")
    }
    public static let unavailable = ReaderError("普通问答服务尚未配置完成，暂不能购买或发送。", "Ordinary Q&A is not configured yet. Purchases and requests are unavailable.")
    public static let unsupported = ReaderError("500 次套餐仅含选文解释和普通追问，不包含全文／阅读总结。", "The 500-question pack covers explanations and ordinary follow-ups, not document or reading summaries.")
    public static func prefix(_ text: String, bytes: Int) -> String {
        var count = 0
        return String(text.prefix { char in count += char.utf8.count; return count <= bytes })
    }
    public static func source(selection: String, context: String, previous: String? = nil, question: String? = nil) -> String {
        if let question {
            return "Current question:\n\(prefix(question, bytes: 1000))\nOriginal selection:\n\(prefix(selection, bytes: 1200))\nSource context:\n\(prefix(context, bytes: 2500))\nPrevious answer (not evidence):\n\(prefix(previous ?? "", bytes: 900))"
        }
        return "Selection:\n\(prefix(selection, bytes: 1600))\nSource context:\n\(prefix(context, bytes: 3800))"
    }
    public static func endpoint(_ text: String?) throws -> URL {
        guard let text, let c = URLComponents(string: text), c.scheme == "https", let host = c.host,
              !host.isEmpty, !host.hasSuffix(".invalid"), !host.hasSuffix(".example"),
              c.user == nil, c.password == nil, c.query == nil, c.fragment == nil,
              c.path.isEmpty || c.path == "/", let url = c.url else { throw unavailable }
        return url
    }
}

private final class GatewayNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor public final class QuestionCredits: ObservableObject {
    public static let shared = QuestionCredits()
    @Published public private(set) var balance: Int?
    @Published public private(set) var product: Product?
    @Published public private(set) var working = false
    @Published public private(set) var message = ""
    @Published public private(set) var recoveredAnswer = ""
    private var listener: Task<Void, Never>?
    private let session: URLSession
    private var initialized = false
    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 100; config.timeoutIntervalForResource = 110
        session = URLSession(configuration: config, delegate: GatewayNoRedirect(), delegateQueue: nil)
    }
    private func report(_ error: Error, english: Bool) {
        message = (error as? ReaderError)?.message(english) ?? (english ? "Could not complete the operation. Try again." : "未能完成操作，请重试。")
    }
    public func start() {
        guard OrdinaryQuestions.enabled, !initialized else { return }
        initialized = true
        listener = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                guard let self else { return }
                do { try await self.deliver(result) }
                catch { self.report(error, english: false) }
            }
        }
    }
    private struct Identity {
        let proof: String
        let root: URL
    }
    private func identity() async throws -> Identity {
        // Check configuration before StoreKit can prompt for an account in an unfinished build.
        let production = try OrdinaryQuestions.endpoint(Bundle.main.object(forInfoDictionaryKey: "DeepReaderGatewayURL") as? String)
        let result = try await AppTransaction.shared
        guard case .verified(let app) = result, !app.appTransactionID.isEmpty else {
            throw ReaderError("无法验证 App Store 账户，请使用商店版并刷新购买。", "Could not verify the App Store account. Use the store edition and refresh purchases.")
        }
        let root: URL
        switch app.environment {
        case .production: root = production
        case .sandbox: root = try OrdinaryQuestions.endpoint(Bundle.main.object(forInfoDictionaryKey: "DeepReaderSandboxGatewayURL") as? String)
        default: throw OrdinaryQuestions.unavailable // Never send local StoreKit testing to a paid API.
        }
        return Identity(proof: result.jwsRepresentation, root: root)
    }
    private func call(_ path: String, method: String = "GET", body: [String: Any]? = nil, identity: Identity) async throws -> [String: Any] {
        var request = URLRequest(url: identity.root.appendingPathComponent("v1/" + path))
        request.httpMethod = method
        request.setValue("Bearer " + identity.proof, forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 100000 else { throw URLError(.dataLengthExceedsMaximum) }
                data.append(byte)
            }
            let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            guard http.statusCode == 200 else { throw Self.failure(value["error"] as? String ?? "network") }
            if let count = value["balance"] as? Int { balance = count }
            return value
        } catch is CancellationError { throw CancellationError() }
        catch let error as ReaderError { throw error }
        catch { throw ReaderError("网络中断。若已发送，可在设置中找回最近回答，避免重复扣次。", "Connection interrupted. Recover the latest answer in Settings before asking again.") }
    }
    public static func failure(_ code: String) -> ReaderError {
        switch code {
        case "insufficient_credits": return ReaderError("次数不足，请在设置中购买 500 次普通问答。", "No questions remaining. Purchase a 500-question pack in Settings.")
        case "daily_limit", "rate_limited": return ReaderError("请求过于频繁或达到每日安全限额，请稍后重试。次数不会过期。", "Rate or daily safety limit reached. Try again later; credits do not expire.")
        case "daily_budget_reached": return ReaderError("问答服务暂时达到容量上限，请稍后重试，本次未扣次数。", "The service reached its daily capacity. Try later; no credit was deducted.")
        case "request_in_progress": return ReaderError("上一条回答仍在生成，请稍后点“找回最近回答”。", "The previous answer is still being generated. Recover it shortly.")
        case "generation_failed_refunded": return ReaderError("回答生成失败，次数已退回。", "Generation failed; the question credit was returned.")
        case "answer_expired": return ReaderError("服务器上的回答副本已清除。已生成的回答不会再次扣次。", "The server answer copy was cleared. It will not be charged again.")
        case "request_not_found": return ReaderError("服务器未收到这条请求，未扣次数。", "The server did not receive this request; no credit was deducted.")
        case "source_too_long": return ReaderError("普通问答内容过长，请缩短选文或问题。", "The ordinary question is too long. Shorten the selection or question.")
        default: return ReaderError("未能验证购买或服务账户，请刷新后重试；如仍失败请联系支持。", "Could not verify the purchase or service account. Refresh and retry, or contact support.")
        }
    }
    public func refresh(english: Bool, synchronize: Bool = false) async {
        guard !working else { return }; working = true; defer { working = false }
        start()
        do {
            if synchronize { try await AppStore.sync(); _ = try await AppTransaction.refresh() }
            let who = try await identity()
            _ = try await call("wallet", identity: who)
            for await transaction in StoreKit.Transaction.unfinished { try await deliver(transaction) }
            product = try await Product.products(for: [OrdinaryQuestions.productID]).first
            message = product == nil ? (english ? "The purchase product is not available yet." : "内购商品暂不可用。") : ""
        } catch { balance = nil; product = nil; report(error, english: english) }
    }
    public func purchase(english: Bool) async {
        guard !working, let product, product.id == OrdinaryQuestions.productID, product.type == .consumable else { return }
        working = true; defer { working = false }
        do {
            let who = try await identity()
            let wallet = try await call("wallet", identity: who)
            guard let text = wallet["accountToken"] as? String, let token = UUID(uuidString: text) else { throw OrdinaryQuestions.unavailable }
            switch try await product.purchase(options: [.appAccountToken(token)]) {
            case .success(let verification):
                try await deliver(verification)
                message = english ? "500 questions added." : "已增加 500 次普通问答。"
            case .pending: message = english ? "Purchase awaiting approval; credits will be added after approval." : "购买等待批准，批准后自动增加次数。"
            case .userCancelled: message = english ? "Purchase cancelled." : "已取消购买。"
            @unknown default: throw OrdinaryQuestions.unavailable
            }
        } catch { report(error, english: english) }
    }
    private func deliver(_ result: VerificationResult<StoreKit.Transaction>) async throws {
        guard case .verified(let transaction) = result, transaction.productID == OrdinaryQuestions.productID,
              transaction.productType == .consumable else { throw Self.failure("invalid_transaction") }
        let who = try await identity()
        if transaction.revocationDate != nil { _ = try await call("wallet", identity: who); await transaction.finish(); return }
        _ = try await call("purchases", method: "POST", body: ["signedTransaction": result.jwsRepresentation], identity: who)
        // Acknowledge to Apple only after the durable server ledger credits this transaction.
        await transaction.finish()
    }
    public func complete(settings: Settings, task: AITask, source: String) async throws -> String {
        guard task == .explain || task == .followup else { throw OrdinaryQuestions.unsupported }
        guard !source.isEmpty, source.utf8.count <= OrdinaryQuestions.maximumSourceBytes else { throw Self.failure("source_too_long") }
        let who = try await identity()
        let identifier = UUID().uuidString.lowercased()
        let value = try await call("questions", method: "POST", body: ["requestId": identifier, "source": source, "task": task.rawValue,
            "english": settings.english, "generalKnowledge": settings.useWorldKnowledge == true], identity: who)
        guard let answer = value["answer"] as? String, !answer.isEmpty else { throw Self.failure("network") }
        return answer
    }
    public func recover(english: Bool) async {
        guard !working else { return }; working = true; defer { working = false }
        do {
            let who = try await identity()
            let result = try await call("questions/latest", identity: who)
            recoveredAnswer = result["answer"] as? String ?? ""
            message = english ? "Recovered without another charge." : "已找回回答，没有再次扣次。"
        } catch { report(error, english: english) }
    }
    public func clearAnswers(english: Bool) async {
        guard !working else { return }; working = true; defer { working = false }
        do {
            _ = try await call("answers", method: "DELETE", identity: identity())
            recoveredAnswer = ""; message = english ? "Server answer copies deleted; balance retained." : "服务器回答副本已删除，次数余额保留。"
        } catch { report(error, english: english) }
    }
}

public struct QuestionCreditsView: View {
    @ObservedObject private var credits = QuestionCredits.shared
    private let english: Bool
    public init(english: Bool) { self.english = english }
    private func t(_ zh: String, _ en: String) -> String { english ? en : zh }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("普通 AI 问答", "Ordinary AI questions")).font(.headline)
            Text(t("剩余次数：", "Questions remaining: ") + (credits.balance.map(String.init) ?? "—"))
            Text(t("500 次选文解释与普通追问 · DeepSeek Flash · 不订阅、不自动续费，次数不过期。", "500 explanations and ordinary follow-ups · DeepSeek Flash · No subscription or automatic renewal. Credits do not expire."))
            Text(t("每条成功回答扣 1 次。仅发送有限的选文、附近语境和上一条回答，不含全文总结或深度思考。失败退回次数；生成成功后取消仍计次，可在 24 小时内找回。每日最多 100 次，剩余次数保留。", "One credit per successful answer. Limited selection, nearby context and the previous answer are sent. Full-document summaries and deep reasoning are excluded. Failures return credits; cancelling after generation still counts. Recover answers within 24 hours. Up to 100 questions per day; remaining credits are retained.")).font(.caption)
            if let product = credits.product {
                Button(t("购买 500 次 · ", "Buy 500 questions · ") + product.displayPrice) { Task { await credits.purchase(english: english) } }.buttonStyle(.borderedProminent)
            } else { Text(t("价格与购买按钮将在连接商店后显示。", "Price and purchase button appear after connecting to the store.")).font(.caption) }
            Button(t("刷新余额与购买", "Refresh balance and purchases")) { Task { await credits.refresh(english: english, synchronize: true) } }
            Button(t("找回最近回答", "Recover latest answer")) { Task { await credits.recover(english: english) } }
            Button(t("清除服务器回答副本", "Clear server answer copies")) { Task { await credits.clearAnswers(english: english) } }
            if credits.working { ProgressView() }
            if !credits.message.isEmpty { Text(credits.message).font(.caption).foregroundStyle(.secondary) }
            if !credits.recoveredAnswer.isEmpty { Text(credits.recoveredAnswer).textSelection(.enabled) }
            Text(t("余额由服务端按 App Store 账户保存，使用相同账户可刷新余额。阅读文件仍保存在本机。", "The server keeps your balance for your App Store account. Refresh with the same account to access it. Reading files stay on your device.")).font(.caption)
        }.disabled(credits.working).task { await credits.refresh(english: english) }
    }
}
