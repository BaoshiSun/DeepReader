// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import UniformTypeIdentifiers

@main struct DeepReaderApp: App {
    @StateObject private var model = MobileModel()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).tint(Color(red: 0.16, green: 0.43, blue: 0.32))
                .onOpenURL { model.importFile($0) }
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
                            Text(model.t("本地阅读 · 按需 AI · 自己的书库", "Local books. Thoughtful reading. Optional AI.")).foregroundStyle(.secondary)
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
        .sheet(isPresented: $model.showAI) { NavigationStack { AssistantView() }.environmentObject(model) }
        .alert(model.t("提示", "Notice"), isPresented: Binding(get: { model.error != nil && !model.showAI }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        .confirmationDialog(model.t("删除应用中的导入副本？原文件保持不变。", "Delete the imported copy? Your original stays unchanged."), isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
            Button(model.t("删除副本", "Delete copy"), role: .destructive) { if let removal { model.deleteBook(removal) }; removal = nil }
        }
    }
}
struct AssistantView: View {
    @EnvironmentObject var model: MobileModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("DeepSeek", systemImage: "sparkles").font(.title2.bold())
                Text(model.t("AI 回答可能出错，请结合原文核对。每次发送前都会请您确认。", "AI can make mistakes. Check the source. You confirm each request before sending.")).font(.footnote).foregroundStyle(.secondary)
                GroupBox(model.t("选中内容", "Selection")) { Text(model.selected.isEmpty ? model.t("返回正文，长按选择一段文字。", "Return to the document and touch and hold to select text.") : model.selected).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                HStack {
                    Button(model.t("解释选文", "Explain")) { model.explain() }.buttonStyle(.borderedProminent).disabled(model.selected.isEmpty || model.busy)
                    Button(model.t("总结全文", "Summarize")) { model.summary() }.buttonStyle(.bordered).disabled(model.busy)
                }
                if model.busy { HStack { ProgressView(); Text(model.progress); Spacer(); Button(model.t("取消", "Cancel")) { model.cancel() } } }
                if !model.answer.isEmpty {
                    Text(model.answer).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    ShareLink(item: model.answer) { Label(model.t("分享回答", "Share answer"), systemImage: "square.and.arrow.up") }
                    TextField(model.t("继续追问…", "Ask a follow-up…"), text: $model.question, axis: .vertical).textFieldStyle(.roundedBorder).disabled(model.busy)
                    Button(model.t("发送追问", "Send follow-up")) { model.followup() }.disabled(model.busy || model.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(22)
        }.navigationTitle(model.t("阅读助手", "Reading assistant")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(model.t("完成", "Done")) { dismiss() } } }
        .sheet(item: $model.pending) { request in
            NavigationStack {
                Form {
                    Section(model.t("发送到 DeepSeek", "Send to DeepSeek")) {
                        Text(model.t("接收方：api.deepseek.com", "Recipient: api.deepseek.com"))
                        Text(model.t("模型：", "Model: ") + request.settings.model)
                        Text(request.task == .document ? model.t("范围：可提取的全文；长文会分段发送并合并摘要。", "Scope: all extractable document text; long documents are split and summaries combined.") : model.t("范围：选文、附近语境；追问还包括之前的回答与问题。", "Scope: selection and context; follow-ups also include the previous answer and question."))
                        Text(model.t("预计请求数：", "Estimated requests: ") + String(request.requests))
                        Text(model.t("API Key 用于关联您的服务商账户。文字和网络信息由服务商按其政策处理，可能保存及用于训练。费用由您的账户承担。", "Your API key identifies your provider account. The provider processes text and network information under its policy, potentially retaining or training on it. Your account pays the fees."))
                        Link(model.t("DeepSeek 隐私政策", "DeepSeek privacy policy"), destination: URL(string: "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html")!)
                    }
                    Section { Button(model.t("同意并发送", "Agree and send")) { model.send(request) }; Button(model.t("取消，继续本地阅读", "Cancel; keep reading locally"), role: .cancel) { model.pending = nil } }
                }.navigationTitle(model.t("发送前确认", "Confirm sharing")).navigationBarTitleDisplayMode(.inline)
            }
        }
        .alert(model.t("提示", "Notice"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
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
    var body: some View {
        Form {
            Section(model.t("界面", "Interface")) {
                Toggle("English", isOn: $model.settings.english).onChange(of: model.settings.english) { model.persistSettings() }
            }
            Section("DeepSeek") {
                Text(model.hasKey ? model.t("API Key 已保存在本机钥匙串", "API key saved in this device's Keychain") : model.t("尚未设置 API Key", "No API key configured"))
                SecureField("API Key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button(model.t("保存 Key", "Save key")) { if model.key(key) { key = "" } }.disabled(key.isEmpty)
                Button(model.t("删除已存 Key", "Remove saved key"), role: .destructive) { model.removeKey() }.disabled(!model.hasKey)
                Picker(model.t("模型", "Model"), selection: Binding(get: { model.settings.model }, set: { model.settings.models[Provider.deepSeek.rawValue] = $0; model.persistSettings() })) { ForEach(Provider.deepSeek.models, id: \.self) { Text($0) } }
                Text(model.t("本地阅读免费且不需要 Key。AI 需您自己的账户，费用和额度由 DeepSeek 决定。", "Local reading needs no key. AI uses your own account; DeepSeek sets fees and quotas.")).font(.footnote)
            }.disabled(model.busy)
            Section(model.t("数据与隐私", "Data and privacy")) {
                Text(model.t("文件导入后存为本机副本。书库、阅读位置、高亮和历史保存在应用容器；不自动同步 Mac。系统备份可能包含这些资料。每次 AI 操作单独确认后才发送文字。", "Imported files are local copies. Books, position, highlights and history stay in the app container; there is no automatic Mac sync. System backups may include these data. Each AI request requires your confirmation."))
                Text(model.t("可在书库长按删除副本，在历史中左滑删除记录，在此移除 Key。卸载应用不保证删除钥匙串中的 Key；服务商数据需向 DeepSeek 申请删除。", "Long-press a book to delete its copy, swipe history to delete records, and remove your key here. Uninstalling may leave Keychain data; contact DeepSeek to delete provider-held data."))
                Link(model.t("服务商隐私政策", "Provider privacy policy"), destination: URL(string: "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html")!)
            }
            Section(model.t("关于", "About")) {
                Text("DeepReader · iOS 1.0.0")
                Text("© 2026 Baoshi Sun")
                Link(model.t("源码与项目说明", "Source code and project"), destination: URL(string: "https://github.com/BaoshiSun/DeepReader/tree/codex/ios-native/ios")!)
                Text(model.t("EPUB 初版采用纯文本章节阅读，暂不显示图片和原书排版；Markdown 显示源文本。暂不支持 MOBI、AZW3、DRM、OCR 或周期总结。", "EPUB uses chapter text; images and original book layout are not displayed yet. Markdown shows source text. MOBI, AZW3, DRM, OCR and period summaries are not supported yet.")).font(.footnote)
                NavigationLink(model.t("开源许可", "Open-source licenses")) { ScrollView { Text(licenses).font(.caption.monospaced()).padding().textSelection(.enabled) }.navigationTitle(model.t("许可", "Licenses")) }
                Link(model.t("支持邮箱", "Support email"), destination: URL(string: "mailto:baoshi.sun@icloud.com")!)
            }
        }.navigationTitle(model.t("设置", "Settings"))
    }
    private var licenses: String {
        ["LICENSE-AGPL-3.0", "ZIPFoundation-LICENSE", "THIRD-PARTY-NOTICES"].compactMap { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: name == "THIRD-PARTY-NOTICES" ? "md" : "txt") else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }.joined(separator: "\n\n")
    }
}
