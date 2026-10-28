# DeepReader 隐私政策 / Privacy Policy

更新日期 / Updated: 2026-10-28。运营者 / Operator: Baoshi Sun。隐私联系 / Privacy contact: [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com)。

本政策适用于 **iOS / iPadOS 1.1.0（构建 5）** 和 **Mac App Store 1.3.1（构建 9）**。是否可下载以 App Store 的实际状态为准。两者均使用随安装包提供的本地 Qwen3 0.6B 模型；iOS 版另有可选的 Google AdMob 书库广告，Mac App Store 版没有广告。旧联网版本及站外下载版适用单独的[其他版本隐私说明](privacy-policy-legacy.md)，不代表本政策所述商店构建的数据处理。

This policy covers **iOS/iPadOS 1.1.0 build 5** and **Mac App Store 1.3.1 build 9**. Availability depends on App Store status. Both bundle Qwen3 0.6B for local AI. The iOS edition separately offers optional Google AdMob library ads; the Mac App Store edition has no ads. Earlier online builds and the separate direct-download edition are described in [other-edition privacy information](privacy-policy-legacy.md); their network behavior does not apply to these store builds.

## 中文

### 本地 AI 处理

解释选文和追问由设备上的 Qwen3 0.6B 量化模型通过 llama.cpp 运行。模型随应用安装，无首次联网下载、远程 AI API、云端备用服务、网络搜索或开发者推理服务器。无需注册、登录、API Key、内购、订阅或购买问答次数。

选文、附近语境、问题和先前回答只在设备上用于生成答案。文档、书名、选文、问题、答案和阅读历史不会为了 AI 推理发送给运营者、Qwen 模型开发者（Alibaba / 通义千问）或任何第三方 AI 服务，也不由本应用上传用于模型训练。“结合通用知识”使用本地模型已学到的知识，不访问网络；“仅书中内容”要求模型依据所提供的文字作答。两种模式都可离线使用，答案都可能不准确或不完整。

### 本地资料与删除

iOS 从“文件”导入的 PDF、EPUB、TXT 和 Markdown 副本保存在本机应用容器，原文件不变。应用还在本机保存书名、阅读位置、评分、读完状态、高亮、语言和显示偏好，以及成功的问答历史。历史可能包括选文、语境、问题、答案、页码和时间。没有开发者提供的云同步或阅读内容分析服务。

Mac App Store 版在本机保存书单、文件访问书签、偏好、高亮和问答历史；仅在您主动保存 PDF、导出或归档时写入所选位置。电子书在本机渲染，应用内文档禁止加载网络资源。升级可能保留旧阅读记录及设置，但本版不读取或发送旧服务商密钥；旧钥匙串条目可能仍留在系统中。

本地资料保留到您删除为止。iOS 可在书库删除导入副本，在历史中单独删除记录；删除书籍不会删除原文件或既有历史。卸载 iOS 应用会移除应用容器。Mac 历史可逐条删除；需要清除全部应用资料时可联系我们获取操作步骤。操作系统账户权限和您启用的设备加密保护本机资料，应用不另行加密阅读数据库。系统备份、您选择的同步目录、导出和归档可能产生额外副本，应在对应服务或位置另行管理；删除本机资料不会删除这些副本。

### iOS 可选广告及接收方

iOS 书库最多显示一条标注“广告”的 Google AdMob 原生图片广告；阅读页、历史、搜索结果和空书库不显示广告。首次开启前，应用说明广告数据处理并提供同意或继续无广告的选择。拒绝、关闭广告或断网都不影响免费阅读和本地 AI。未开启广告时，不初始化 Google 广告及同意管理 SDK，也不请求广告。

开启后，Google Mobile Ads 和 Google User Messaging Platform（UMP）会联网，由 Google 提供广告及适用地区的隐私选择。广告和同意管理服务可能处理 IP 地址及据此推断的大致位置、设备或应用范围标识、广告展示与点击、产品交互、性能、崩溃及其他诊断资料，用于投放广告、效果衡量、服务改进、诊断及防欺诈。资料可能关联设备并在您所在国家以外处理。**应用不把书名、文档、选文、阅读语境、问题、答案或阅读历史加入广告请求或提供给 Google。Google 在本应用中提供广告服务，不是 AI 推理服务。**

我们请求非个性化广告和限制数据处理，关闭发布商第一方 ID，不请求 Apple 广告跟踪权限，不提供 GPS 位置。未接入 Firebase Analytics 或第三方广告聚合网络。非个性化广告仍可能处理上述数据，并不等于不收集数据。

可在“设置 → 书库广告”关闭新的广告请求；在适用地区可通过“管理 Google 隐私选择”重新选择。Google 按其[隐私政策](https://policies.google.com/privacy)和[合作伙伴广告数据说明](https://policies.google.com/technologies/partner-sites)处理资料并提供安全措施、保留规则及访问和删除选项。关闭广告或删除本机资料不能撤回 Google 已收到的数据。运营者无法访问 Google 保存的单个用户广告日志；有关 Google 所持资料的请求应使用其隐私政策中的渠道。

### 主动分享与联系

只有您主动分享、导出或打开支持/源代码链接时，所选应用、网站或收件人才可能接收相关资料，并适用其隐私规则。Apple 的下载、系统备份及其他系统服务适用 Apple 的政策。

如果您给支持邮箱发邮件，运营者会收到您的邮箱地址、消息和附件，仅用于处理支持或隐私请求，保留至请求处理及必要后续跟进结束；可联系同一邮箱请求删除。请勿发送凭据或不必要的私人文档。公开 GitHub Issue 会公开您提交的内容，请勿在那里提交个人信息。

功能或数据处理方式变化时会更新本政策并标明日期。隐私问题及删除请求请联系 baoshi.sun@icloud.com。

## English

### On-device AI

Explanations and follow-up answers are generated on your device by the bundled, quantized Qwen3 0.6B model using llama.cpp. There is no first-use model download, remote AI API, cloud fallback, web search or developer inference server. No account, login, API key, purchase, subscription or question credits are required.

Selected text, nearby context, questions and prior answers are processed on the device to generate answers. Documents, book titles, selections, questions, answers and reading history are not sent for AI inference to the operator, the model developer (Alibaba / Qwen), or any third-party AI service. The app does not upload them for model training. General knowledge uses knowledge already learned by the local model, without Internet access. Book only asks the model to use the supplied text. Both modes work offline and may produce inaccurate or incomplete answers.

### Local storage and deletion

On iOS, copies of PDF, EPUB, TXT and Markdown files imported from Files are stored in the local app container; originals are unchanged. The app also stores titles, reading positions, ratings, finished status, highlights, language/display preferences and successful answer history locally. History may contain selections, context, questions, answers, page numbers and timestamps. There is no developer cloud sync or reading-content analytics service.

The Mac App Store edition locally stores book lists, file-access bookmarks, preferences, highlights and answer history. Saving PDFs, exports and archives writes only to locations you choose when you request it. Ebooks render locally with network document resources blocked. Updates may preserve earlier reading data/settings but this build does not read or transmit old provider keys; earlier Keychain entries may remain.

Local data remains until you delete it. On iOS, delete imported copies in Library and records separately in History; removing a book does not delete its original file or existing history. Uninstalling the iOS app removes its container. On Mac, individual History records can be deleted; contact support for steps to remove all app data. OS account permissions and enabled device encryption protect local files; the app does not separately encrypt its reading database. System backups, chosen synced folders, exports and archives may hold extra copies. Manage these at their respective locations; local deletion does not delete those copies.

### Optional iOS advertising and recipients

The iOS library may display one clearly labelled Google AdMob native image ad. There are no ads in the reader, History, search results or an empty library. Before ads are enabled, an in-app explanation offers agreement or continued use without ads. Declining, disabling ads or going offline preserves all free reading and local AI features. Until enabled, the app does not initialize Google's advertising/consent SDKs or request ads.

When enabled, Google Mobile Ads and Google User Messaging Platform (UMP) connect to Google for advertising and applicable regional privacy choices. Advertising and consent services may process IP addresses and inferred coarse location, device/app identifiers, ad views and clicks, product interactions, performance, crashes and other diagnostic data for advertising, measurement, service improvement, diagnostics and fraud prevention. Data may be associated with a device and processed internationally. **The app does not include book titles, documents, selections, reading context, questions, answers or reading history in advertising requests or supply them to Google. Google provides advertising here, not AI inference.**

We request non-personalized ads and restricted data processing, disable publisher first-party ID, do not request Apple's tracking permission and supply no GPS location. Firebase Analytics and third-party mediation networks are not integrated. Non-personalized advertising can still process the data described above.

Settings → Library ads stops new ad requests. Manage Google privacy choices lets you revisit choices where applicable. Google's [privacy policy](https://policies.google.com/privacy) and [partner data notice](https://policies.google.com/technologies/partner-sites) describe its processing, security measures, retention, access and deletion options. Disabling ads or deleting local data cannot recall data already received by Google. The operator cannot access Google's per-user ad logs; use Google's privacy channels for requests about data it holds.

### Sharing and support you initiate

Sharing, exports and external support/source links use the apps, sites or recipients you choose, which may receive the selected information under their own privacy rules. Apple's downloads, system backups and other system services are covered by Apple's policies.

If you email support, the operator receives your email address, message and attachments solely to handle your support or privacy request, keeping them until the request and necessary follow-up are complete. Contact the same address to request deletion. Do not send credentials or unnecessary private documents. GitHub Issues are public; do not post personal information there.

This policy will be updated and dated when features or processing change. Send privacy questions and deletion requests to baoshi.sun@icloud.com.
