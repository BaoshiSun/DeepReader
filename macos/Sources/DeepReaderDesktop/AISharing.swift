// SPDX-License-Identifier: AGPL-3.0-or-later
import AppKit
import DeepReaderCore

public enum AISharingDecision { case cancel, sendOnce, rememberRecipient }

public enum AISharingKind: Equatable {
    public static let consentVersion = 1
    case selection, followup, document, history

    func description(english: Bool) -> String {
        switch self {
        case .selection: return english ? "Selected text and nearby document context" : "选中文字及附近的文档上下文"
        case .followup: return english ? "Your question, original selection, context and previous answers" : "本次问题、原选文、上下文和此前的回答"
        case .document: return english ? "All text extracted from the current document, sent in multiple requests if needed" : "从当前文档提取的全部文字（可能分多次请求发送）"
        case .history: return english ? "Saved selections, answers, document titles and dates in the selected period" : "所选时段内已保存的选文、回答、文档标题和日期"
        }
    }

    @MainActor public static func confirm(_ settings: Settings, _ kind: AISharingKind) -> AISharingDecision {
        let en = settings.english
        let alert = NSAlert()
        alert.messageText = en ? "Send this data to \(settings.provider.rawValue)?" : "将这些内容发送给 \(settings.provider.rawValue)？"
        let routing = settings.provider == .openRouter
            ? (en ? " OpenRouter also forwards requests to the model providers it selects." : " OpenRouter 还会将请求转发给其选用的模型供应商。") : ""
        alert.informativeText = kind.description(english: en) + "\n\n" +
            (en ? "Recipient: " : "接收方：") + settings.provider.rawValue + "\n" + settings.endpointText + "\n" +
            (en ? "Model: " : "模型：") + settings.model + "\n\n" +
            (en ? "Your API key authenticates the request. The service receives your IP address and may retain the submitted content under its own policy. Provider fees or quotas apply." : "请求使用您的 API Key 验证身份。服务商会收到 IP 地址，并可能按其政策保留提交的内容；费用和额度由服务商决定。") + routing + "\n\n" +
            (en ? "Choose Allow and remember to authorize future AI actions for this provider and endpoint: explanations send selections and context; follow-ups include the question and conversation; document summaries send extracted full text; reading summaries send saved passages, answers, titles and dates. Nothing is sent until you request an AI action. You can revoke permission in Setup. Changing the recipient requires new permission. Cancelling later cannot recall data already sent." : "选择“同意并记住”后，此服务商和接口地址的后续 AI 操作不再询问：解释发送选文及上下文；追问还包括问题与对话；全文总结发送提取的全文；阅读总结发送保存的选文、回答、标题和日期。仍只在您主动使用 AI 功能时发送。可在设置中撤销授权，更换接收方需重新确认。发送后取消无法撤回已传出的数据。")
        if OrdinaryQuestions.enabled {
            alert.messageText = en ? "Send reading content to DeepReader and DeepSeek?" : "将阅读内容发送给 DeepReader 和 DeepSeek？"
            alert.informativeText = kind.description(english: en) + "\n\n" + (en
                ? "DeepReader forwards limited reading context to DeepSeek Flash. The server verifies purchases and manages credits; one credit is used per successful answer. Failed generation returns the credit. Answers are encrypted on the server for up to 24 hours to recover interrupted requests; clear them in Settings. DeepSeek processes content under its own policy. No provider key is stored in this app.\n\nAllow and remember applies to future questions. You can revoke permission in Setup. Cancelling after generation still counts; recover the answer in Setup."
                : "DeepReader 服务器将有限的阅读语境转发给 DeepSeek Flash。服务器验证购买并管理次数，每条成功回答扣 1 次，生成失败退回次数。回答在服务器加密暂存最多 24 小时用于断线找回，可在设置中清除；DeepSeek 按其政策处理内容。App 不保存服务商密钥。\n\n同意并记住后适用于之后主动发起的问答，可在设置中撤销。生成成功后取消仍计次，可在设置中找回回答。")
        }
        alert.addButton(withTitle: en ? "Cancel" : "取消")
        alert.addButton(withTitle: en ? "Allow and remember, send" : "同意并记住，发送")
        alert.addButton(withTitle: en ? "Send this time only" : "仅本次发送")
        switch alert.runModal() {
        case .alertSecondButtonReturn: return .rememberRecipient
        case .alertThirdButtonReturn: return .sendOnce
        default: return .cancel
        }
    }
}
