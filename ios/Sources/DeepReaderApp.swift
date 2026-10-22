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
    @StateObject private var ads = LibraryAdvertising.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var importing = false
    @State private var search = ""
    @State private var removal: MobileBook?
    private var filteredBooks: [MobileBook] { model.books.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) } }
    private var libraryEligible: Bool {
        LibraryAdPolicy.eligible(tab: selectedTab, reading: model.document != nil, bookCount: model.books.count,
                                 searching: !search.isEmpty, busy: model.busy || model.importing || importing, active: scenePhase == .active)
    }
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.t("留一点时间，\n读懂更多。", "Make room\nfor a good read.")).font(.system(size: 34, weight: .semibold, design: .serif))
                            Text(model.t("内置千问 · 免费离线问答", "Built-in Qwen · Free offline AI")).foregroundStyle(.secondary)
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
                        LazyVStack(spacing: 16) {
                            ForEach(Array(filteredBooks.enumerated()), id: \.element.id) { index, book in
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
                                if libraryEligible, LibraryAdPolicy.slot(after: index, bookCount: filteredBooks.count, searching: !search.isEmpty), let ad = ads.nativeAd {
                                    LibraryNativeAdRow(ad: ad, english: model.english)
                                }
                            }
                        }
                    }.padding(22)
                }.background(Color(.systemGroupedBackground))
                .navigationTitle(model.t("书库", "Library"))
                .searchable(text: $search, prompt: model.t("搜索书名", "Search books"))
                .navigationDestination(isPresented: Binding(get: { model.document != nil }, set: { if !$0 { model.closeBook() } })) { ReaderScreen() }
            }.tabItem { Label(model.t("书库", "Library"), systemImage: "books.vertical") }.tag(0)
            NavigationStack { HistoryView() }.tabItem { Label(model.t("历史", "History"), systemImage: "clock") }.tag(1)
            NavigationStack { SettingsView() }.tabItem { Label(model.t("设置", "Settings"), systemImage: "gearshape") }.tag(2)
        }
        .task(id: libraryEligible) { ads.setLibraryVisible(libraryEligible) }
        .sheet(isPresented: Binding(get: { libraryEligible && ads.configured && ads.needsDisclosure }, set: { _ in })) {
            AdvertisingConsentSheet(ads: ads)
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
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                    Text(model.t("AI 答案可能不准确或不完整，仅供参考，请核对原文。", "AI answers may be inaccurate or incomplete. Use them as a reference and check the original text.")).font(.caption).foregroundStyle(.secondary)
                    KnowledgeScopePicker()
                    if !model.selected.isEmpty {
                        Text(model.selected).font(.subheadline).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        Text(model.t("在正文中长按选择文字，再点解释。", "Touch and hold text in the document, then tap Explain.")).font(.subheadline)
                    }
                    HStack {
                        Button { model.explain() } label: { Text(model.t("解释选文", "Explain")).foregroundStyle(.white) }
                            .buttonStyle(.borderedProminent).tint(Color(red: 0.16, green: 0.43, blue: 0.32)).disabled(model.selected.isEmpty || model.busy)
                    }
                    if model.busy { HStack { ProgressView(); Text(model.progress).font(.caption); Spacer(); Button(model.t("取消", "Cancel")) { model.cancel() } } }
                    if !model.answer.isEmpty {
                        Text(model.answerSubject).font(.caption.weight(.semibold)).lineLimit(2).foregroundStyle(.secondary)
                        Text(model.answer).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        ShareLink(item: model.answer) { Label(model.t("分享回答", "Share answer"), systemImage: "square.and.arrow.up") }.font(.caption)
                        TextField(model.t("继续追问…", "Ask a follow-up…"), text: $model.question, axis: .vertical).lineLimit(1...4).textFieldStyle(.roundedBorder).disabled(model.busy)
                        Button(model.t("发送追问", "Send follow-up")) { model.followup() }.disabled(model.busy || model.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text(model.t("Qwen3 0.6B · 本机离线运行 · 免费使用，无问答次数限制", "Qwen3 0.6B · On device · Free, no question quota")).font(.caption2).foregroundStyle(.secondary)
                if let error = model.error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                    Button(model.t("知道了", "Dismiss notice")) { model.error = nil }.font(.caption)
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }.scrollDismissesKeyboard(.interactively)

    }
}
struct HistoryView: View {
    @EnvironmentObject var model: MobileModel
    @State private var search = ""
    var body: some View {
        List {
            if model.records.isEmpty { Text(model.t("成功的解释和追问会保存在这里。", "Successful explanations and follow-ups appear here.")).foregroundStyle(.secondary) }
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
    @ObservedObject private var ads = LibraryAdvertising.shared
    @State private var advertisingConsent = false
    var body: some View {
        Form {
            Section(model.t("界面", "Interface")) {
                Toggle("English", isOn: $model.settings.english).onChange(of: model.settings.english) { model.persistSettings() }
            }
            Section(model.t("本机 AI", "On-device AI")) {
                KnowledgeScopePicker()
                    Text(LocalEdition.name).font(.headline)
                    Text(model.t("答案可能不准确或不完整，请核对原文，不要仅凭 AI 回答作出重要决定。", "Answers may be inaccurate or incomplete. Check the original text and do not rely solely on AI for important decisions.")).font(.callout)
                    Text(model.t("模型已内置，完全免费，无订阅或问答次数限制，可在飞行模式下使用。书库可展示广告，阅读页面不展示广告。", "Model included. Free, with no subscriptions or question quota. Works in airplane mode. Ads may appear in the library, never in the reader."))
                    Text(model.t("本机问答取选文前 500 字、附近语境前 600 字；追问前 300 字及上次回答前 250 字。小模型适合简单释义，专业知识与计算可能不准确。首次回答需加载模型，生成时会增加耗电。", "On-device limits: first 500 characters of selection, 600 of context, 300 of follow-up and 250 of previous answer. Best for simple explanations; technical knowledge and calculations may be unreliable. Loading and generation use battery."))
            }.disabled(model.busy)
            Section(model.t("书库广告", "Library ads")) {
                Toggle(model.t("允许书库广告", "Allow library ads"), isOn: Binding(get: { ads.enabled }, set: { value in
                    if value { advertisingConsent = true } else { ads.choose(false) }
                }))
                NavigationLink(model.t("广告与隐私", "Ads and privacy")) { AdvertisingPrivacyView() }
                if ads.privacyOptionsRequired {
                    Button(model.t("管理 Google 隐私选择", "Manage Google privacy choices")) { ads.showPrivacyOptions() }.disabled(ads.privacyBusy)
                }
                Text(model.t("仅书库列表展示一条标注为“广告”的内容，不影响阅读和免费 AI。", "One clearly labelled ad may appear among your books. Reading and free AI are unaffected.")).font(.footnote)
            }
            Section(model.t("数据与隐私", "Data and privacy")) {
                    Link(model.t("隐私政策", "Privacy policy"), destination: URL(string: "https://github.com/BaoshiSun/DeepReader/blob/codex/ios-library-admob/docs/app-store/privacy-policy.md")!)
                    Text(model.t("阅读和 AI 推理都在设备上完成，不发送原文或问题。书库和历史保存在本机，系统备份可能包含这些资料。可在书库和历史中删除记录。", "Reading and inference run on your device. Text and questions are not sent out. Books and history stay locally and may be included in system backups. Delete them from Library and History."))
            }
            Section(model.t("关于", "About")) {
                Text("DeepReader · iOS \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")")
                Text("© 2026 Baoshi Sun")
                Link(model.t("源码与项目说明", "Source code and project"), destination: URL(string: "https://github.com/BaoshiSun/DeepReader/tree/codex/ios-library-admob/ios")!)
                Text(model.t("EPUB 初版采用纯文本章节阅读，暂不显示图片和原书排版；Markdown 显示源文本。暂不支持 MOBI、AZW3、DRM、OCR 或周期总结。", "EPUB uses chapter text; images and original book layout are not displayed yet. Markdown shows source text. MOBI, AZW3, DRM, OCR and period summaries are not supported yet.")).font(.footnote)
                NavigationLink(model.t("开源许可", "Open-source licenses")) { ScrollView { Text(licenses).font(.caption.monospaced()).padding().textSelection(.enabled) }.navigationTitle(model.t("许可", "Licenses")) }
                Link(model.t("支持邮箱", "Support email"), destination: URL(string: "mailto:baoshi.sun@icloud.com")!)
            }
        }.navigationTitle(model.t("设置", "Settings"))
        .sheet(isPresented: $advertisingConsent) { AdvertisingConsentSheet(ads: ads) }
        .alert(model.t("暂时无法打开隐私选项，请稍后重试。", "Privacy options are unavailable. Please try again later."), isPresented: $ads.privacyError) { Button("OK") {} }
    }
    private var licenses: String {
        ["LICENSE-AGPL-3.0", "ZIPFoundation-LICENSE", "THIRD-PARTY-NOTICES", "AdvertisingPrivacy", "Qwen-LICENSE", "llama-LICENSE"].compactMap { name in
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
