// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Compiled only into the offline macOS package (GitHub and App Store).
public final class AIClient: @unchecked Sendable {
    private let modelURL: URL?
    public init(modelURL: URL? = nil) { self.modelURL = modelURL }
    public static var unsupported: ReaderError {
        ReaderError("本机小模型提供选文解释和追问，暂不支持全文或周期总结。",
                    "The local small model supports passage explanations and follow-ups, not document or period summaries.")
    }
    public static func source(selection: String, context: String, previous: String = "", question: String = "") -> String {
        var text = "Selected passage:\n\(TextLimits.prefix(selection, 500))\nNearby context:\n\(TextLimits.prefix(context, 600))"
        if !question.isEmpty {
            text += "\nPrevious answer (fallible history):\n\(String(previous.suffix(250)))\nCurrent question:\n\(TextLimits.prefix(question, 300))"
        }
        return text
    }
    public func complete(settings: Settings, key: String, task: AITask, source: String) async throws -> String {
        guard task == .explain || task == .followup else { throw Self.unsupported }
        return try await LocalQwen.shared.complete(settings: settings, source: source,
                                                   followup: task == .followup, modelURL: modelURL)
    }
}
