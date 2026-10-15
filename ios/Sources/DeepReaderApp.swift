// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import UniformTypeIdentifiers

@main struct DeepReaderApp: App {
    @StateObject private var model = MobileModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).tint(Color(red: 0.16, green: 0.43, blue: 0.32))
                .onOpenURL { model.importFile($0) }
                .onAppear { if !model.localAI { QuestionCredits.shared.start() } }
        }
    }
}
struct RootView: View {
    @EnvironmentObject var model: MobileModel
    @State private var importing = false
    @State private var search = ""
    @State private var removal: MobileBook?
    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.t("留一点时间，\n读懂更多。", "Make room\nfor a good read.")).font(.system(size: 34, weight: .semibold, design: .serif))
                            Text(model.localAI ? model.t("千问已内置 · 离线问答 · 无需 Key", "Qwen included. Offline answers. No API key.") : model.t("本地阅读 · 按需 AI · 自己的书库", "Local books. Thoughtful reading. Optional AI.")).foregroundStyle(.secondary)
                        }.padding(.top, 12)
                        Button { importing = true } label: { Label(model.t("从文件导入", "Import from Files"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(6) }.buttonStyle(.borderedProminent).disabled(model.importing || model.busy || model.library == nil)
                        if model.importing { ProgressView(model.t("正在导入…", "Importing…")) }
                        if model.books.isEmpty {
                            VStack(spacing: 14) {
                                Image(systemName: "books.vertical").font(.system(size: 50)).foregroundStyle(.secondary)
                                Text(model.t("您的书库，从第一本开始", "Your library starts with one book")).font(.headline)
                                Text("PDF · EPUB · TXT · Markdown").font(.subheadline).foregroundStyle(.secondary)
                                Button(model.t("打开示例文章", "Read a sample")) { model.sample() }.disabled(model.library == nil)
                            }.frame(maxWidth: .infinity).padding(.vertical, 38)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 16)], spacing: 16) {
                            ForEach(model.books.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }) { book in
                                Button { model.open(book) } label: {
                                    HStack(alignment: .top, spacing: 16) {
                                        Image(systemName: book.filename.hasSuffix("pdf") ? "doc.richtext" : "book.closed")
                                            .font(.title).frame(width: 52, height: 72).background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(book.title).font(.headline).lineLimit(2).foregroundStyle(.primary)
                                            Text(book.finished ? model.t("已读完", "Finished") : model.t("阅读中", "Reading")).font(.caption).foregroundStyle(.secondary)
                                            if book.rating > 0 { Text(String(repeating: "★", count: book.rating)).font(.caption).foregroundStyle(.orange) }
                                        }; Spacer(minLength: 0)
                                    }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                                }.buttonStyle(.plain).disabled(model.busy)
                                .contextMenu { Button(role: .destructive) { removal = book } label: { Label(model.t("删除导入副本", "Delete imported copy"), systemImage: "trash") } }
                            }
                        }
                    }.padding(22)
                }.background(Color(.systemGroupedBackground))
                .navigationTitle(model.t("书库", "Library"))
                .searchable(text: $search, prompt: model.t("搜索书名", "Search books"))
                .navigationDestination(isPresented: Binding(get: { model.document != nil }, set: { if !$0 { model.closeBook() } })) { ReaderScreen() }
            }.tabItem { Label(model.t("书库", "Library"), systemImage: "books.vertical") }
            NavigationStack { HistoryView() }.tabItem { Label(model.t("历史", "History"), systemImage: "clock") }
            NavigationStack { SettingsView() }.tabItem { Label(model.t("设置", "Settings"), systemImage: "gearshape") }
        }
        .disabled(model.importing)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .plainText, UTType(filenameExtension: "epub") ?? .data, UTType(filenameExtension: "md") ?? .plainText], allowsMultipleSelection: false) { result in
            do { if let url = try result.get().first { model.importFile(url) } } catch { model.report(error) }
        }
        .alert(model.t("提示", "Notice"), isPresented: Binding(get: { model.error != nil && !model.showAI }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .confirmationDialog(model.t("删除应用中的导入副本？原文件保持不变。", "Delete the imported copy? Your original stays unchanged."), isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
            Button(model.t("删除副本", "Delete copy"), role: .destructive) { if let removal { model.deleteBook(removal) }; removal = nil }
        }
    }
}
struct AssistantView: View {
    @EnvironmentObject var model: MobileModel
    @State private var showCredits = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let request = model.pending {
                    if model.storeQuestions {
                        Text(model.t("允许将阅读内容发送给 DeepReader 和 DeepSeek？", "Send reading content to DeepReader and DeepSeek?")).font(.headline)
                        Text(model.t("选文、附近语境和追问由 DeepReader 服务器转发给 DeepSeek。服务器验证购买并管理次数；成功回答扣 1 次。服务器加密暂存回答最多 24 小时用于断线找回，可在设置中清除；DeepSeek 按其政策处理内容。", "DeepReader forwards selected text, nearby context and follow-ups to DeepSeek. The server verifies purchases and manages credits; successful answers cost one credit. Answers are encrypted on the server for up to 24 hours for recovery and can be cleared in Settings. DeepSeek processes content under its policy."))
                        Text(model.t("仅在主动提问时发送，可在设置中撤销授权。", "Sent only when you ask. Revoke permission in Settings."))
                    } else {
                    Text(model.t("允许将阅读内容发送到 ", "Allow reading content to be sent to ") + request.settings.provider.rawValue + "?").font(.headline)
                    Text(model.t("解释发送选文和附近语境；追问还发送先前回答和问题；点击“总结全文”会发送可提取的全文，长文分段处理。", "Explanations send your selection and nearby context; follow-ups also send the previous answer and question. Summarize sends all extractable text, split for long documents."))
                    Text(request.settings.endpointText + " · " + request.settings.model).font(.caption)
                    Text(model.t("本次预计请求数：", "Estimated requests now: ") + String(request.requests)).font(.caption)
                    Text(model.t("内容和网络信息由所选服务商按其政策处理，可能保存及用于训练；API 费用由您的账户承担。", "The selected provider processes content and network information under its policy, potentially retaining or training on it. Your account pays API fees.")).font(.footnote)
                    Text(model.t("OpenRouter 会将内容转发给模型供应商。自定义地址由该服务器运营者处理。请先查阅服务商的隐私政策与条款。", "OpenRouter forwards content to model providers. Custom endpoints are operated by their server owner. Review the provider’s privacy policy and terms first.")).font(.footnote)
                    Text(model.t("记住授权后，仅在您点击解释、追问或总结时发送，不再逐次询问。可在设置中撤销。", "Remembering permission skips future prompts when you tap Explain, Follow-up or Summarize. Revoke it in Settings at any time.")).font(.footnote)
                    }
                    Button { model.authorizeAndSend(request) } label: { Text(model.t("同意并记住，发送", "Allow, remember and send")).foregroundStyle(.white) }
                        .buttonStyle(.borderedProminent).tint(Color(red: 0.16, green: 0.43, blue: 0.32))
                    Button(model.t("暂不发送", "Not now")) { model.pending = nil }
                } else {
                    Text(model.t("AI 答案可能不准确或不完整，仅供参考，请核对原文。", "AI answers may be inaccurate or incomplete. Use them as a reference and check the original text.")).font(.caption).foregroundStyle(.secondary)
                    KnowledgeScopePicker()
                    if model.storeQuestions {
                        Button(model.t("问答次数与购买", "Question balance and purchase")) { showCredits = true }.font(.caption)
                    }
                    if !model.selected.isEmpty {
                        Text(model.selected).font(.subheadline).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        Text(model.t("在正文中长按选择文字，再点解释。", "Touch and hold text in the document, then tap Explain.")).font(.subheadline)
                    }
                    HStack {
                        Button { model.explain() } label: { Text(model.t("解释选文", "Explain")).foregroundStyle(.white) }
                            .buttonStyle(.borderedProminent).tint(Color(red: 0.16, green: 0.43, blue: 0.32)).disabled(model.selected.isEmpty || model.busy)
                        if !model.storeQuestions && !model.localAI { Menu {
                            Button(model.t("发送全文并总结", "Send full text and summarize")) { model.summary() }
                        } label: { Label(model.t("全文总结", "Summary"), systemImage: "doc.text") }.disabled(model.busy) }
                    }
                    if model.busy { HStack { ProgressView(); Text(model.progress).font(.caption); Spacer(); Button(model.t("取消", "Cancel")) { model.cancel() } } }
                    if !model.answer.isEmpty {
                        Text(model.answerSubject).font(.caption.weight(.semibold)).lineLimit(2).foregroundStyle(.secondary)
                        Text(model.answer).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        ShareLink(item: model.answer) { Label(model.t("分享回答", "Share answer"), systemImage: "square.and.arrow.up") }.font(.caption)
                        TextField(model.t("继续追问…", "Ask a follow-up…"), text: $model.question, axis: .vertical).lineLimit(1...4).textFieldStyle(.roundedBorder).disabled(model.busy)
                        Button(model.t("发送追问", "Send follow-up")) { model.followup() }.disabled(model.busy || model.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text(model.localAI ? model.t("Qwen3 0.6B · 本机离线运行 · 不消耗次数", "Qwen3 0.6B · On device · No credits needed") : model.hasAIConsent ? model.settings.provider.rawValue + model.t(" · 已记住发送授权", " · Sharing permission remembered") : model.t("首次发送前会征求授权", "Permission is requested before the first send")).font(.caption2).foregroundStyle(.secondary)
                }
                if let error = model.error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                    Button(model.t("知道了", "Dismiss notice")) { model.error = nil }.font(.caption)
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }.scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showCredits) { NavigationStack { ScrollView { QuestionCreditsView(english: model.english).padding() }.navigationTitle(model.t("普通问答", "Ordinary questions")).toolbar { Button(model.t("完成", "Done")) { showCredits = false } } } }
    }
}
struct HistoryView: View {
    @EnvironmentObject var model: MobileModel
    @State private var search = ""
    var body: some View {
        List {
            if model.records.isEmpty { Text(model.t("成功的解释和总结会保存在这里。", "Successful explanations and summaries appear here.")).foregroundStyle(.secondary) }
            ForEach(model.records.filter { $0.matches(search) }) { record in
                NavigationLink {
                    ScrollView { Text(record.text(english: model.english)).frame(maxWidth: .infinity, alignment: .leading).padding().textSelection(.enabled) }
                        .navigationTitle(record.title).toolbar { ShareLink(item: record.text(english: model.english)) { Image(systemName: "square.and.arrow.up") } }
                } label: { VStack(alignment: .leading, spacing: 5) { Text(record.title).font(.headline); Text(record.answer).lineLimit(2).foregroundStyle(.secondary); Text(record.time.prefix(10)).font(.caption) } }
                .swipeActions { Button(role: .destructive) { model.deleteRecord(record.id) } label: { Label(model.t("删除", "Delete"), systemImage: "trash") } }
            }
        }.navigationTitle(model.t("阅读历史", "Reading history")).searchable(text: $search)
    }
}
struct SettingsView: View {
    @EnvironmentObject var model: MobileModel
    @State private var key = ""
    @State private var modelID = ""
    @State private var endpoint = ""
    var body: some View {
        Form {
            Section(model.t("界面", "Interface")) {
                Toggle("English", isOn: $model.settings.english).onChange(of: model.settings.english) { model.persistSettings() }
            }
            Section(model.t("AI 服务", "AI provider")) {
                KnowledgeScopePicker()
                if model.localAI {
                    Text(LocalEdition.name).font(.headline)
                    Text(model.t("答案可能不准确或不完整，请核对原文，不要仅凭 AI 回答作出重要决定。", "Answers may be inaccurate or incomplete. Check the original text and do not rely solely on AI for important decisions.")).font(.callout)
                    Text(model.t("模型已内置，可在飞行模式下使用，无需 API Key 或购买次数。", "Model included. Works in airplane mode without an API key or purchases."))
                    Text(model.t("本机问答取选文前 500 字、附近语境前 600 字；追问前 300 字及上次回答前 250 字。小模型适合简单释义，专业知识与计算可能不准确。首次回答需加载模型，生成时会增加耗电。", "On-device limits: first 500 characters of selection, 600 of context, 300 of follow-up and 250 of previous answer. Best for simple explanations; technical knowledge and calculations may be unreliable. Loading and generation use battery."))
                } else if model.storeQuestions {
                    QuestionCreditsView(english: model.english)
                } else {
                Picker(model.t("服务商", "Provider"), selection: Binding(get: { model.settings.provider }, set: {
                    model.chooseProvider($0); loadDrafts()
                })) { ForEach(Provider.available()) { Text($0.rawValue).tag($0) } }
                Text(model.hasKey ? model.t("当前地址已有 Key；留空保留", "Key saved for this endpoint; leave empty to keep") : model.t("当前地址尚未设置 Key", "No key saved for this endpoint"))
                SecureField("API Key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                if !model.settings.provider.models.isEmpty {
                    Picker(model.t("常用模型", "Model preset"), selection: Binding(get: { model.settings.provider.models.contains(modelID) ? modelID : "custom" }, set: { if $0 != "custom" { modelID = $0 } })) {
                        ForEach(model.settings.provider.models, id: \.self) { Text($0).tag($0) }
                        Text(model.t("自定义", "Custom")).tag("custom")
                    }
                }
                TextField(model.t("模型 ID / 推理接入点 ID", "Model ID / deployment ID"), text: $modelID).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(model.t("完整 HTTPS 接口地址", "Full HTTPS endpoint"), text: $endpoint).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).disabled(Provider.isAppStoreBuild)
                Text(Provider.isAppStoreBuild
                     ? model.t("商店版使用服务商的预设直连接口；请使用与该地址匹配的 Key。", "The store edition uses preset direct provider endpoints. Use a key for the displayed endpoint.")
                     : model.t("支持文字对话模型；地址需与服务商及 Key 匹配。修改地址后需为新地址保存 Key。", "Text chat models are supported. Match the endpoint to your provider and key. A new endpoint needs its own saved key.")).font(.footnote)
                if model.settings.provider.requiresAdultConfirmation {
                    Toggle(model.t("我已满 18 岁", "I am 18 or older"), isOn: Binding(get: { model.settings.adultConfirmed == true }, set: { model.settings.adultConfirmed = $0; model.persistSettings() }))
                    Link(model.t("服务商条款", "Provider terms"), destination: model.settings.provider.termsURL!)
                }
                Button(model.t("保存 AI 设置", "Save AI settings")) {
                    if model.saveAIConfiguration(model: modelID, endpoint: endpoint, key: key) { loadDrafts() }
                }
                Button(model.t("删除当前已存 Key", "Remove current saved key"), role: .destructive) { model.removeKey() }.disabled(!model.hasKey)
                if model.settings.provider != .custom { Link(model.t("服务商控制台", "Provider console"), destination: model.settings.provider.keyURL) }
                Text(model.t("本地阅读不需要 Key。AI 使用您的服务商账户和额度；聊天订阅通常不包含 API 费用。", "Local reading needs no key. AI uses your provider account and quota; chat subscriptions generally do not include API fees.")).font(.footnote)
                }
            }.disabled(model.busy)
            Section(model.t("数据与隐私", "Data and privacy")) {
                if model.localAI {
                    Link(model.t("隐私政策", "Privacy policy"), destination: URL(string: "https://github.com/BaoshiSun/DeepReader/blob/codex/ios-offline-qwen-store/docs/app-store/privacy-policy.md")!)
                    Text(model.t("阅读和 AI 推理都在设备上完成，不发送原文或问题。书库和历史保存在本机，系统备份可能包含这些资料。可在书库和历史中删除记录。", "Reading and inference run on your device. Text and questions are not sent out. Books and history stay locally and may be included in system backups. Delete them from Library and History."))
                } else {
                Link(model.t("DeepReader 隐私政策", "DeepReader privacy policy"), destination: URL(string: "https://github.com/BaoshiSun/DeepReader/blob/codex/main/docs/app-store/privacy-policy.md")!)
                if model.hasAIConsent {
                    Label(model.settings.provider.rawValue + model.t(" · 已授权", " · Sharing allowed"), systemImage: "checkmark.shield")
                    Button(model.t("撤销 AI 发送授权", "Revoke AI sharing permission"), role: .destructive) { model.revokeAIConsent() }
                } else {
                    Text(model.t("尚未授权 AI 发送；首次使用时会询问。", "AI sharing is not authorized; you will be asked on first use."))
                }
                Text(model.t("文件导入后存为本机副本。书库、阅读位置、高亮和历史保存在应用容器；不自动同步 Mac。系统备份可能包含这些资料。AI 首次发送时征求授权并记住；之后仅在点击解释、追问或总结时发送，可随时撤销授权。", "Imported files are local copies. Books, position, highlights and history stay in the app container; there is no automatic Mac sync. System backups may include these data. AI sharing permission is requested once and remembered. Text is sent only when you tap Explain, Follow-up or Summarize; permission can be revoked."))
                if model.storeQuestions {
                    Text(model.t("购买记录和次数余额由 DeepReader 服务器保存；不接收完整书库，不保存提问原文。回答加密暂存最多 24 小时，可在问答设置中立即清除。Apple 处理付款；DeepSeek 处理主动提交的阅读内容。", "DeepReader stores purchase records and credit balances, not your library or question text. Answer copies are encrypted for up to 24 hours and can be cleared immediately in question settings. Apple processes payments; DeepSeek processes the reading content you submit."))
                } else {
                Text(model.t("可在书库长按删除副本，在历史中左滑删除记录，在此移除 Key。卸载应用不保证删除钥匙串中的 Key；服务商数据需向相应服务商申请删除。", "Long-press a book to delete its copy, swipe history to delete records, and remove your key here. Uninstalling may leave Keychain data; contact the selected provider to delete provider-held data."))
                }
                Text(model.t("切换接收方后需重新授权。", "A different recipient requires fresh permission."))
                }
            }
            Section(model.t("关于", "About")) {
                Text("DeepReader · iOS \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")")
                Text("© 2026 Baoshi Sun")
                Link(model.t("源码与项目说明", "Source code and project"), destination: URL(string: "https://github.com/BaoshiSun/DeepReader/tree/codex/ios-offline-qwen-store/ios")!)
                Text(model.t("EPUB 初版采用纯文本章节阅读，暂不显示图片和原书排版；Markdown 显示源文本。暂不支持 MOBI、AZW3、DRM、OCR 或周期总结。", "EPUB uses chapter text; images and original book layout are not displayed yet. Markdown shows source text. MOBI, AZW3, DRM, OCR and period summaries are not supported yet.")).font(.footnote)
                NavigationLink(model.t("开源许可", "Open-source licenses")) { ScrollView { Text(licenses).font(.caption.monospaced()).padding().textSelection(.enabled) }.navigationTitle(model.t("许可", "Licenses")) }
                Link(model.t("支持邮箱", "Support email"), destination: URL(string: "mailto:baoshi.sun@icloud.com")!)
            }
        }.navigationTitle(model.t("设置", "Settings")).onAppear { loadDrafts() }
    }
    private func loadDrafts() {
        key = ""; modelID = model.settings.model; endpoint = model.settings.endpointText
    }
    private var licenses: String {
        ["LICENSE-AGPL-3.0", "ZIPFoundation-LICENSE", "THIRD-PARTY-NOTICES", "Qwen-LICENSE", "llama-LICENSE"].compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: name == "THIRD-PARTY-NOTICES" ? "md" : "txt") else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n\n")
    }
}
struct KnowledgeScopePicker: View {
    @EnvironmentObject var model: MobileModel
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker(model.t("回答依据", "Answer sources"), selection: Binding(get: { model.settings.useWorldKnowledge == true }, set: { model.setWorldKnowledge($0) })) {
                Text(model.t("仅书中内容", "Book only")).tag(false)
                Text(model.t("结合通用知识", "Add general knowledge")).tag(true)
            }.pickerStyle(.menu).disabled(model.busy)
            Text(model.t("用于之后的回答；通用知识不联网搜索。", "Applies to future answers; general knowledge does not browse the web.")).font(.caption).foregroundStyle(.secondary)
        }
    }
}
