// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import DeepReaderCore

public enum AISharingKind: Equatable {
    case selection, followup, document, history

    func description(english: Bool) -> String {
        switch self {
        case .selection: return english ? "Selected text and nearby document context" : "选中文字及附近的文档上下文"
        case .followup: return english ? "Your question, original selection, context and previous answers" : "本次问题、原选文、上下文和此前的回答"
        case .document: return english ? "All text extracted from the current document, sent in multiple requests if needed" : "从当前文档提取的全部文字（可能分多次请求发送）"
        case .history: return english ? "Saved selections, answers, document titles and dates in the selected period" : "所选时段内已保存的选文、回答、文档标题和日期"
        }
    }

    @MainActor public static func confirm(_ settings: Settings, _ kind: AISharingKind) -> Bool {
        let en = settings.english
        let alert = NSAlert()
        alert.messageText = en ? "Send this data to \(settings.provider.rawValue)?" : "将这些内容发送给 \(settings.provider.rawValue)？"
        let routing = settings.provider == .openRouter
            ? (en ? " OpenRouter also forwards requests to the model providers it selects." : " OpenRouter 还会将请求转发给其选用的模型供应商。") : ""
        alert.informativeText = kind.description(english: en) + "\n\n" +
            (en ? "Recipient: " : "接收方：") + settings.provider.rawValue + "\n" +
            (en ? "Model: " : "模型：") + settings.model + "\n\n" +
            (en ? "Your API key authenticates the request. The service receives your IP address and may retain the submitted content under its own policy. Provider fees or quotas apply." : "请求使用您的 API Key 验证身份。服务商会收到 IP 地址，并可能按其政策保留提交的内容；费用和额度由服务商决定。") + routing + "\n\n" +
            (en ? "Consent applies only to this operation. Cancel to keep reading offline. Cancelling a request later cannot recall data already sent." : "同意仅适用于本次操作。取消后仍可离线阅读。发送后再取消请求，无法撤回已经传出的数据。")
        alert.addButton(withTitle: en ? "Cancel" : "取消")
        alert.addButton(withTitle: en ? "Agree and send" : "同意并发送")
        return alert.runModal() == .alertSecondButtonReturn
    }
}
