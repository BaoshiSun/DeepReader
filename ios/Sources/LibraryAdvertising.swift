// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

/// No book data enters this object or an advertising request.
enum LibraryAdPolicy {
    static func slot(after index: Int, bookCount: Int, searching: Bool) -> Bool {
        !searching && bookCount > 0 && index == min(3, bookCount) - 1
    }
    static func eligible(tab: Int, reading: Bool, bookCount: Int, searching: Bool, busy: Bool, active: Bool) -> Bool {
        tab == 0 && !reading && bookCount > 0 && !searching && !busy && active
    }
    static func fresh(loadedAt: Date?, now: Date) -> Bool {
        guard let loadedAt else { return false }
        return now.timeIntervalSince(loadedAt) >= 0 && now.timeIntervalSince(loadedAt) < 55 * 60
    }
}

@MainActor final class LibraryAdvertising: NSObject, ObservableObject, NativeAdLoaderDelegate {
    static let shared = LibraryAdvertising()
    @Published private(set) var nativeAd: NativeAd?
    @Published private(set) var choice: String
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var privacyBusy = false
    @Published var privacyError = false
    private let defaults: UserDefaults
    private var libraryVisible = false
    private var consentReady = false
    private var sdkStarted = false
    private var starting = false
    private var consentUpdating = false
    private var loader: AdLoader?
    private var loadedAt: Date?
    private var lastAttempt: Date?
    private var expiry: Task<Void, Never>?
    private var revision = 0
    private let choiceKey = "libraryAdvertisingChoice.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        choice = defaults.string(forKey: "libraryAdvertisingChoice.v1") ?? "undecided"
        super.init()
    }
    var enabled: Bool { choice == "allowed" }
    var needsDisclosure: Bool { choice == "undecided" && !preview && !testing }
    var configured: Bool {
        let app = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
        return app.hasPrefix("ca-app-pub-") && app.contains("~") && unitID.hasPrefix("ca-app-pub-") && unitID.contains("/")
    }
    private var unitID: String { Bundle.main.object(forInfoDictionaryKey: "DeepReaderNativeAdUnitID") as? String ?? "" }
    private var testing: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil }
    private var preview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--admob-test-preview")
        #else
        return false
        #endif
    }
    func setLibraryVisible(_ visible: Bool) {
        libraryVisible = visible
        if !visible {
            // Detach pending callbacks. Cached ads never become visible in a reader.
            loader?.delegate = nil; loader = nil
            return
        }
        if !LibraryAdPolicy.fresh(loadedAt: loadedAt, now: Date()) { clearAd() }
        guard configured, !testing else { return }
        if preview { consentReady = true; startIfAllowed(); return }
        guard enabled else { return }
        if consentReady { startIfAllowed() } else { updateConsent() }
    }
    func choose(_ allow: Bool) {
        revision += 1
        choice = allow ? "allowed" : "declined"
        defaults.set(choice, forKey: choiceKey)
        consentReady = false
        clearAd()
        lastAttempt = nil
        if allow && libraryVisible && !testing { updateConsent() }
    }
    private func clearAd() {
        loader?.delegate = nil; loader = nil
        nativeAd = nil; loadedAt = nil
        expiry?.cancel(); expiry = nil
    }
    private func updateConsent() {
        guard !consentUpdating, enabled, configured else { return }
        consentUpdating = true
        let token = revision
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.consentUpdating = false
                guard token == self.revision, self.enabled else { return }
                self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                // A failed update never blocks reading or starts ads using stale consent.
                guard error == nil else { return }
                guard self.libraryVisible else { return }
                self.privacyBusy = true
                do { try await ConsentForm.loadAndPresentIfRequired(from: nil) }
                catch { self.privacyBusy = false; return }
                self.privacyBusy = false
                guard token == self.revision, self.enabled else { return }
                self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                self.consentReady = ConsentInformation.shared.canRequestAds
                self.startIfAllowed()
            }
        }
    }
    func showPrivacyOptions() {
        guard !privacyBusy, privacyOptionsRequired, !testing else { return }
        revision += 1
        let token = revision
        clearAd(); consentReady = false; privacyBusy = true
        Task { @MainActor in
            do { try await ConsentForm.presentPrivacyOptionsForm(from: nil) }
            catch { privacyError = true }
            privacyBusy = false
            guard token == revision else { return }
            privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
            consentReady = enabled && ConsentInformation.shared.canRequestAds
            lastAttempt = nil
            startIfAllowed()
        }
    }
    private func startIfAllowed() {
        guard libraryVisible, (enabled || preview), consentReady, configured, !testing else { return }
        guard !starting else { return }
        if sdkStarted { loadIfNeeded(); return }
        starting = true
        MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
        MobileAds.shared.requestConfiguration.maxAdContentRating = .general
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.starting = false; self.sdkStarted = true
                self.loadIfNeeded()
            }
        }
    }
    private func loadIfNeeded() {
        guard libraryVisible, (enabled || preview), consentReady, !privacyBusy, loader == nil, nativeAd == nil else { return }
        if let lastAttempt, Date().timeIntervalSince(lastAttempt) < 60 { return }
        lastAttempt = Date()
        let video = VideoOptions(); video.shouldStartMuted = true
        let placement = NativeAdViewAdOptions(); placement.preferredAdChoicesPosition = .topRightCorner
        let next = AdLoader(adUnitID: unitID, rootViewController: nil, adTypes: [.native], options: [video, placement])
        loader = next; next.delegate = self
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1", "rdp": "1"]
        request.register(extras)
        next.load(request)
    }
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        guard loader === adLoader, libraryVisible, (enabled || preview), consentReady else { return }
        loader = nil
        self.nativeAd = nativeAd; loadedAt = Date()
        expiry?.cancel()
        expiry = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(55 * 60)) } catch { return }
            self?.clearAd() // Refresh only on a subsequent library visit, never while reading.
        }
    }
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        guard loader === adLoader else { return }
        loader = nil
        #if DEBUG
        print("Library test ad unavailable: \(error.localizedDescription)")
        #endif
    }
}

struct LibraryNativeAdRow: UIViewRepresentable {
    let ad: NativeAd
    let english: Bool
    func makeUIView(context: Context) -> BookNativeAdView { BookNativeAdView() }
    func updateUIView(_ view: BookNativeAdView, context: Context) { view.display(ad, english: english) }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: BookNativeAdView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        return uiView.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }
    static func dismantleUIView(_ view: BookNativeAdView, coordinator: ()) { view.nativeAd = nil }
}

/// Only SDK-registered assets receive clicks. The card background is never a Button.
final class BookNativeAdView: NativeAdView {
    private let badge = UILabel()
    private let headline = UILabel()
    private let advertiser = UILabel()
    private let icon = UIImageView()
    private let cta = UIButton(type: .system)
    private let media = MediaView()
    private let content = UIStackView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 18
        // Do not clip the SDK's AdChoices overlay.
        badge.font = .preferredFont(forTextStyle: .caption1)
        badge.adjustsFontForContentSizeCategory = true
        badge.textAlignment = .center; badge.textColor = .secondaryLabel
        badge.layer.borderWidth = 1; badge.layer.cornerRadius = 4
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.accessibilityIdentifier = "library-ad-badge"
        headline.font = .preferredFont(forTextStyle: .headline)
        headline.adjustsFontForContentSizeCategory = true
        headline.numberOfLines = 0
        advertiser.font = .preferredFont(forTextStyle: .caption1)
        advertiser.adjustsFontForContentSizeCategory = true
        advertiser.textColor = .secondaryLabel; advertiser.numberOfLines = 0
        icon.contentMode = .scaleAspectFit
        icon.layer.cornerRadius = 10; icon.clipsToBounds = true
        cta.configuration = .tinted()
        cta.configuration?.baseForegroundColor = UIColor(red: 0.16, green: 0.43, blue: 0.32, alpha: 1)
        cta.titleLabel?.numberOfLines = 0
        cta.titleLabel?.adjustsFontForContentSizeCategory = true
        cta.isUserInteractionEnabled = false // Google SDK handles clicks.
        cta.setContentHuggingPriority(.required, for: .horizontal)
        let top = UIStackView(arrangedSubviews: [badge, UIView()]); top.axis = .horizontal
        // Dedicated top row leaves the top-right corner free for AdChoices.
        let action = UIStackView(arrangedSubviews: [cta, UIView()]); action.axis = .horizontal
        let text = UIStackView(arrangedSubviews: [headline, advertiser, action]); text.axis = .vertical; text.spacing = 7
        let row = UIStackView(arrangedSubviews: [icon, text]); row.alignment = .top; row.spacing = 16
        content.axis = .vertical; content.spacing = 10
        [top, row, media].forEach(content.addArrangedSubview)
        addSubview(content); content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 38),
            badge.heightAnchor.constraint(greaterThanOrEqualToConstant: 22),
            icon.widthAnchor.constraint(equalToConstant: 52), icon.heightAnchor.constraint(equalToConstant: 52),
            media.heightAnchor.constraint(equalToConstant: 180)
        ])
        headlineView = headline; iconView = icon; advertiserView = advertiser
        callToActionView = cta; mediaView = media
        accessibilityIdentifier = "library-native-ad"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func display(_ ad: NativeAd, english: Bool) {
        badge.text = english ? "Ad" : "广告"
        badge.layer.borderColor = UIColor.secondaryLabel.cgColor
        headline.text = ad.headline
        advertiser.text = ad.advertiser; advertiser.isHidden = ad.advertiser == nil
        icon.image = ad.icon?.image; icon.isHidden = ad.icon == nil
        cta.configuration?.title = ad.callToAction; cta.isHidden = ad.callToAction == nil
        media.mediaContent = ad.mediaContent
        media.isHidden = !ad.mediaContent.hasVideoContent
        // Bind only after every asset has been assigned.
        if nativeAd !== ad { nativeAd = ad }
    }
}

struct AdvertisingPrivacyView: View {
    @EnvironmentObject var model: MobileModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(model.t("书库中的广告帮助支持应用维护。阅读和本机千问问答仍免费使用。", "Library ads help support the app. Reading and on-device Qwen remain free."))
                Text(model.t("启用广告后，Google AdMob 可能处理 IP 地址推断的大致位置、设备或应用标识、广告展示与点击、使用和诊断数据，用于广告投放、衡量和防欺诈。数据可能在其他国家处理。我们只请求非个性化广告，不申请广告跟踪权限，也不向广告服务发送书名、文档、选文、问题或回答。", "When enabled, Google AdMob may process coarse location inferred from IP, device or app identifiers, ad views and clicks, usage and diagnostics for advertising, measurement and fraud prevention. Data may be processed in other countries. We request non-personalized ads, do not request tracking permission, and never send book titles, documents, selections, questions or answers to the ad service."))
                Text(model.t("您可以拒绝，或随时在设置中关闭书库广告；阅读和 AI 不受影响。关闭会停止新的广告请求，无法收回广告服务已收到的数据。部分地区还会显示 Google 的隐私选择。", "You may decline or turn off library ads in Settings at any time without losing reading or AI. Turning ads off stops new ad requests, but cannot recall data already received. Additional Google privacy choices may appear in some regions."))
                Link(model.t("Google 隐私政策", "Google privacy policy"), destination: URL(string: "https://policies.google.com/privacy")!)
                Link(model.t("Google 广告数据使用说明", "How Google uses advertising data"), destination: URL(string: "https://policies.google.com/technologies/partner-sites")!)
            }.padding()
        }.navigationTitle(model.t("广告与隐私", "Ads and privacy"))
    }
}

struct AdvertisingConsentSheet: View {
    @EnvironmentObject var model: MobileModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var ads: LibraryAdvertising
    var body: some View {
        NavigationStack {
            AdvertisingPrivacyView()
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 10) {
                        Button(model.t("同意并开启书库广告", "Agree and enable library ads")) { ads.choose(true); dismiss() }
                            .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                        Button(model.t("暂不开启，继续免费阅读", "Continue free reading without ads")) { ads.choose(false); dismiss() }
                    }.padding().frame(maxWidth: .infinity).background(.regularMaterial)
                }
        }.interactiveDismissDisabled()
    }
}
