# DeepReader 隐私政策 / Privacy Policy

更新日期 / Updated: 2026-10-23。适用于 macOS 1.3.1（Mac App Store 构建 9 为离线版，构建 8 为旧联网版），以及 iOS / iPadOS 1.1.0（按构建号区分）；同时保留旧版行为的说明。运营者 / Operator: Baoshi Sun。隐私联系邮箱 / Privacy contact: [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com)。是否已开放下载，请以 App Store 中的实际状态为准。旧 GitHub 预览版的功能及数据位置有所不同，下文明确区分。

## iOS / iPadOS 1.1.0（构建 5）：离线 AI 与书库广告 / Offline AI and library ads

本节仅适用于新增书库广告的 iOS 构建 5，优先于旧版本说明。内置 Qwen3 0.6B 仍在设备上运行，阅读和问答全部免费，无登录、API Key、内购、订阅或次数配额。文档副本、书名、选文、问题、回答、阅读位置和历史不发送给 Google 或远程 AI；保存在设备上，系统备份和用户主动分享需另行管理。

书库列表最多展示一条标注“广告”的 Google AdMob 原生图片广告。阅读、历史、搜索结果和空书库不显示广告。首次在有书籍的书库使用广告前，会说明广告数据处理并请求您的选择；可以拒绝，并随时在设置关闭广告，不影响阅读和 AI。未开启时不初始化广告或同意管理 SDK、不请求广告。开启后先通过 Google User Messaging Platform（UMP）检查适用的地区隐私选择；无法完成时不加载广告。广告无填充或断网不会阻止使用。

广告及同意管理服务可能处理 IP 地址及由其推断的大致位置、设备或应用范围标识、广告展示与点击、产品使用情况、性能、崩溃及其他诊断资料，用于广告投放、效果衡量、诊断和防欺诈。数据可能关联到设备，并在您所在国家以外处理。我们请求非个性化广告和限制数据处理，关闭发布商第一方 ID，不请求 Apple 广告跟踪权限，不提供 GPS 位置或阅读内容。非个性化广告仍涉及上述数据处理，并不等同于“不收集数据”。未接入 Firebase Analytics 或第三方广告聚合网络。

可在“设置 → 书库广告”关闭之后的新广告请求，并在需要的地区通过“管理 Google 隐私选择”更改同意选项。关闭或删除本机资料无法撤回 Google 已收到的数据；Google 的保留、访问及删除规则见 [Google 隐私政策](https://policies.google.com/privacy) 和 [合作伙伴广告数据说明](https://policies.google.com/technologies/partner-sites)。运营者无法访问 Google 保存的单个用户广告日志。联系我们：baoshi.sun@icloud.com。

This section takes precedence for iOS/iPadOS 1.1.0 build 5. Bundled Qwen3 0.6B continues to run locally. Reading and AI remain free with no login, API key, purchase, subscription or question quota. Documents, book titles, selections, questions, answers, reading positions and history are not sent to Google or a remote AI service. They remain local; manage system backups and user-initiated sharing separately.

The library may show one clearly labelled Google AdMob native image ad. No ads appear in the reader, History, search results or an empty library. Before enabling ads, an explanation lets you agree or decline. You can turn ads off in Settings without losing any reading or AI features. Until enabled, the app does not initialize the ads/consent SDKs or request ads. When enabled, Google UMP checks applicable privacy choices before ads load. Consent failures, unavailable ads and offline use never block reading.

Advertising and consent services may process IP-derived coarse location, device/app identifiers, ad views and clicks, product interactions, performance, crash and diagnostic information for advertising, measurement, diagnostics and fraud prevention. Data may be associated with a device and processed internationally. We request non-personalized ads and restricted data processing, disable publisher first-party ID, do not request Apple's tracking permission, and supply neither GPS location nor reading content. Non-personalized advertising still involves data collection. Firebase Analytics and third-party mediation networks are not integrated.

Settings → Library ads stops new requests; Manage Google privacy choices is available where required. Stopping ads or deleting local data cannot recall data already received by Google. Retention, access and deletion are governed by the [Google privacy policy](https://policies.google.com/privacy) and [partner data notice](https://policies.google.com/technologies/partner-sites). The operator cannot access Google's per-user ad logs. Privacy contact: baoshi.sun@icloud.com.

## Mac App Store 1.3.1（构建 9）：离线 AI / Offline AI

此节优先适用于 Mac App Store 构建 9。它内置 Qwen3 0.6B 模型，解释和追问在 Mac 本机处理。无需账户、API Key、购买次数或服务器；无广告、订阅、遥测或分析 SDK。没有远程 AI 客户端或联网备用服务，模型随应用安装。电子书使用 WebKit 本地渲染，应用内文档禁止加载网络资源；主动打开支持或源代码链接时，系统浏览器会按对应网站政策联网。

原始文档由用户选择，应用保存本地书单、文件访问书签、阅读偏好、高亮及问答记录。PDF 保存或归档仅在用户主动操作时写入所选文件或目录；不会上传书籍、问题或答案。历史可在应用内逐条删除，导出副本和系统备份需另行管理。更新后保留旧阅读记录及偏好，但不读取或发送旧服务商密钥。旧版钥匙串数据可能仍留在系统中；本版本不删除旧凭据。GitHub 下载版仍采用下文的自带 API Key 联网方式。

This section takes precedence for Mac App Store 1.3.1 build 9. Bundled Qwen3 0.6B generates explanations and follow-ups entirely on the Mac. No account, API key, purchases, server, ads, subscriptions, telemetry or analytics SDK is used. No remote AI client or network fallback is included; the model is installed with the app. Ebooks render locally in WebKit with network document resources blocked. User-initiated support/source links open in the system browser under the destination site's policy.

User-selected documents remain local. Book lists, file-access bookmarks, preferences, highlights and answer history are stored locally. Saving PDFs or archiving writes only when requested by the user. Books, questions and answers are not uploaded. Delete records in History; exported copies and system backups require separate management. Updates retain old reading data/preferences but do not read or transmit old provider keys; older Keychain entries may remain and are not deleted by this version. The GitHub direct-download edition retains the separately described bring-your-own-key network behavior.

## iOS / iPadOS 1.1.0（构建 3、4）：离线 AI / Offline AI

本节优先适用于 iOS / iPadOS 1.1.0（构建 3、4）及 DeepReader Local 离线版。下文联网模型、API Key 和开发中的内购服务器说明不适用于此离线版本；Mac App Store 构建 9 按上节说明；GitHub macOS 和旧构建按下文对应章节说明。

本版内置 Qwen3 0.6B 量化模型，解释和追问完全在设备上处理。无需注册、登录、API Key、内购或远程 AI 服务，不上传文档、选文、问题或回答供 AI 推理，不采集这些内容用于训练。没有开发者后端、广告、追踪或分析 SDK。模型随安装包提供，不在首次使用时联网下载。

用户导入的书籍副本、阅读位置、高亮、偏好和问答历史保存在本机应用容器，系统备份可能包含这些资料。可在书库删除导入副本，在历史中删除记录；原始文件保持不变。卸载应用会移除应用容器，但不会自动删除已有系统备份。主动使用分享、导出或打开支持链接时，所选择的系统应用、网站或收件人可能接收相关资料；请按自己的意愿操作。Apple 的商店下载和系统服务适用 Apple 的政策。若主动通过邮箱联系支持，运营者只使用您提供的信息处理请求；请勿发送私人文档或凭据。

This section takes precedence for iOS/iPadOS 1.1.0 builds 3 and 4 and the DeepReader Local offline edition. Descriptions below of network providers, personal API keys and the unreleased purchase backend do not apply to this edition. Mac App Store build 9 follows the preceding section; direct-download macOS and older builds retain their separately described behavior.

A bundled, quantized Qwen3 0.6B model generates explanations and follow-ups on the device. There is no registration, login, API key, in-app purchase or remote AI service. Documents, selections, questions and answers are not uploaded for AI inference or collected for training. There is no developer backend, advertising, tracking or analytics SDK, and no first-use model download.

Imported copies, reading positions, highlights, preferences and answer history stay in the local app container and may be included in system backups. Delete copies in Library and records in History; original files are preserved. Uninstalling removes the app container, not existing system backups. Optional sharing, export and external support links use the apps, sites or recipients you explicitly choose, which may receive the selected information. Apple download/system services are covered by Apple's policies. Information voluntarily emailed to support is used to address that request; please do not send private documents or credentials.

## 普通问答内购版（开发中，尚未发布） / Purchased-question edition (unreleased)

2026-10-15：以下说明仅适用于未发布的实验性内购分支，不适用于 iOS 构建 3；原计划的 Apple 商店内购版本，并取代下文旧版本中的“自带 API Key”“直接连接多服务商”和“不运营代理服务器”的描述。部署地点与正式生效版本尚待确定，发布前必须补全；下文旧版本行为继续适用于对应旧构建和站外版本。

普通问答由 DeepReader 服务器转发至 DeepSeek Flash。用户主动同意后，解释发送有限长度的选文和附近语境，追问还发送当前问题和上一条回答。不会上传整个书库或文档文件，不提供套餐内全文总结。运营者的 API Key 只保存在服务器，用户无需提供 Key。Apple 处理内购付款，DeepReader 不接收银行卡号。

为了校验购买、恢复跨设备余额、防止重复发放次数，服务器接收 Apple 签名的 App 下载与购买凭据，保存不可直接识别姓名的账户关联标识、交易编号、购买次数、余额、请求时间及状态。不会读取 Apple 账户密码或邮箱。购买与账户标识属于关联用户的购买历史／标识数据，应更新 App Store 隐私标签。退款可能撤销相应次数。

提问原文只在服务器内存中转发，不写入应用数据库。成功回答加密暂存约 24 小时用于断线找回，可在 App 中立即清除；用户本机已保存的历史不会随服务器副本清除。账务与防滥用记录单独保留；具体法定保留期限和托管日志政策须在正式部署前确定并告知用户。服务器不记录 API Key、Apple 签名凭据、授权请求头或原文。临时网络限流使用哈希 IP，约一小时后清除。托管方可能处理连接 IP 等网络数据。

DeepSeek 会收到提交的阅读内容和服务器的网络信息，按其政策处理；用户本机 IP 由 DeepReader 服务器接收。DeepReader 不承诺 DeepSeek 零保存或不训练。处理地区与跨境情况需结合部署地点说明。隐私与删除请求仍联系 baoshi.sun@icloud.com。

For the unreleased Apple in-app-purchase edition, this section supersedes legacy descriptions of personal keys, direct multi-provider requests and no developer relay. Deployment location and the effective release version must be specified before launch. DeepReader forwards limited, explicitly requested reading passages/context and follow-up questions/previous answers to DeepSeek Flash. Full libraries and document files are not uploaded; document summaries are excluded. The developer key remains server-side. Apple processes payment; DeepReader does not receive card numbers.

The service verifies Apple-signed app and purchase proofs, retaining a pseudonymous account association, transaction IDs, purchased credits, balances, request times and state for delivery, cross-device balance recovery and fraud prevention. No Apple password or email is collected. These linked identifiers and purchase-history data require updated App Store privacy disclosures. Refunds may revoke credits. Question text is forwarded in memory; encrypted answers are retained for approximately 24 hours for recovery and can be cleared in-app immediately. Local history is separate. Accounting-record retention and hosting/logging policies must be finalized before deployment. No raw proofs, authorization headers, keys or question text are logged by the application. Temporary hashed-IP limit records are deleted after approximately one hour. DeepSeek's own retention/processing policies apply; no zero-retention or no-training promise is made. Contact the operator for privacy/deletion requests.

## macOS 1.3.1 与旧 iOS 1.1.0 构建 2 多模型支持 / Multiple providers

2026-10-13：macOS 1.3.1 和 iOS / iPadOS 1.1.0 提供下述多模型支持；旧 iOS / iPadOS 1.0.0 构建仅支持 DeepSeek。

macOS 1.3.1 和 iOS 1.1.0 在用户主动执行 AI 操作时，将相同范围的文字发送给设置中选定的服务商及完整 HTTPS 地址。可选 DeepSeek、OpenAI、Anthropic Claude、Google Gemini、Qwen、Kimi、GLM、Doubao、MiniMax、xAI Grok、Mistral、OpenRouter 或用户配置的兼容服务器。DeepReader 不运营 AI 代理服务器。自定义服务器的运营者及其下游服务可能接收内容；OpenRouter 将请求路由到模型供应商。不要向不信任的地址填写 Key 或发送文档。

服务商接收认证 Key、发送的文字、IP 地址及连接所需信息。保存、训练、日志、账号关联和跨境处理由实际接收方的政策与账户设置决定；本应用不承诺各家均不保存或不训练。用户应先在服务商网站查看条款和隐私政策。服务商保存的数据需向该服务商申请删除。

Apple 版 Key 按服务商与地址隔离保存于本机钥匙串；模型 ID 与接口地址保存在本机设置中。iOS 的发送授权绑定服务商和地址，改变接收方需要新授权，可在设置中撤销；旧版全局授权不自动用于新服务商。macOS 新版支持绑定接收方的记住授权，并保留“仅本次发送”；旧版仍逐次确认。仅修改设置或选择文字不会发起模型请求。Gemini 与 OpenRouter 的成人使用确认不替代对服务条款、整体受众和上架年龄分级的复核。

This section applies to macOS 1.3.1 and iOS / iPadOS 1.1.0, including the App Store builds. The older iOS / iPadOS 1.0.0 build is DeepSeek-only. On an explicit AI action, the current builds send the same text scopes to the selected provider and full HTTPS endpoint: DeepSeek, OpenAI, Anthropic Claude, Google Gemini, Qwen, Kimi, GLM, Doubao, MiniMax, xAI Grok, Mistral, OpenRouter, or a user-configured compatible server. DeepReader operates no AI proxy. OpenRouter forwards requests to model providers; custom server operators may also use downstream services.

Recipients receive authentication credentials, submitted text, IP addresses and connection information. Retention, training, logging, account linkage and international processing depend on the actual recipient’s policies and account settings. Review those policies before sharing; contact the recipient to delete provider-held data. Apple builds isolate Keychain credentials by provider and endpoint. iOS remembers permission for a recipient, supports revocation and requires fresh permission for changed recipients; legacy global consent is not reused. macOS 1.3.1 supports remembered permission for the current provider and endpoint, one-operation permission and revocation in Setup; older store builds ask per operation. Selecting text or editing settings sends no AI request. Age confirmation for Gemini and OpenRouter does not by itself establish compliance with all provider terms or store requirements.

## macOS — 中文

### 本机阅读和保存

DeepReader 是文档与电子书阅读器，不要求创建 DeepReader 账户。打开、查找、评分、阅读状态、书单和本地归档不需要调用 AI。当前应用没有内置广告或分析统计 SDK，不将阅读库发送给 DeepReader 维护者，也不提供自有云同步。

应用在本机保存设置、文档路径和标题、评分、阅读状态和日期、归档路径、电子书高亮，以及成功的解释、追问与总结。解释记录可能包含选文、语境、回答、时间、页码、服务商和模型名称。归档会在您指定的位置另存原格式文件；导出的记录可能含文件名和原文。

商店版的数据位于系统分配的应用容器，另保存文件授权书签；不会自动导入站外版资料。当前站外版数据位于 `~/Library/Application Support/DeepReader/`。这些记录不由应用另行加密；操作系统账户权限及您启用的磁盘加密提供保护。系统备份、您选择的同步目录、手动导出和归档可能产生额外副本。

API Key 单独保存在 macOS 钥匙串，不写入设置 JSON 或公开发行包。发起 AI 请求时，所选服务商会接收该服务的 Key 用于身份验证。

### 何时向 AI 服务发送数据

macOS 1.3.1 起可选择“同意并记住，发送”，授权仅绑定当前服务商和完整接口地址，适用于后续主动发起的解释、追问、全文总结及阅读记录总结。授权保存在本机，重启后仍有效；可在设置中撤销，也可选择“仅本次发送”或取消。未授权的新接收方需要重新确认，旧版的单次同意不会自动升级为记住授权。

旧商店构建 1.2.1（5）在每次 AI 操作前要求同意；macOS 1.3.1 在尚未授权当前接收方时显示接收方、模型及内容范围，选择允许后才发送；取消仍可离线阅读。旧的 1.2.1 GitHub 预览版仅在主动触发 AI 操作时发送，尚无新增的逐次同意弹窗。数据直接由本机发送给所选服务的 API，而不是经过 DeepReader 自有服务器。

| 操作 | 发送内容 |
| --- | --- |
| 解释选文 | 选中的文字、附近语境及回答语言等指令 |
| 继续追问 | 当前问题、原选文与语境、已有对话 |
| 文件总结 | 可提取的全文；长文按段请求并发送中间摘要进行合并 |
| 日／周／月总结 | 所选时间范围的已保存选文、回答、记录时间和记录标题 |

不会上传文档二进制文件；程序不主动将本机完整目录路径加入提示词。但原文本身可能包含个人信息，周期总结中的标题可能来自文件名。服务商也会接收网络连接所必需的信息，例如 IP 地址和请求时间。DeepSeek 可能将请求与 API Key 所属账户关联，保留使用量和技术诊断日志，并根据 IP 推断粗略位置用于安全与防滥用；DeepReader 不请求 GPS 位置。服务商可能为功能提供、分析和改进服务处理数据，包括其政策允许的模型训练。商店隐私标签因此申报用户内容、用户标识、使用数据、诊断数据和粗略位置；不将本地阅读视为上述数据的自动上传。

旧商店构建 1.2.1（5）仅提供 DeepSeek；macOS 1.3.1 支持本政策开头列出的服务商及自定义兼容接口。DeepSeek 的保存期限、日志、训练使用、跨境处理和删除机制由其适用条款及账号设置决定；DeepReader 不承诺零保存或不用于训练。请阅读 [DeepSeek 隐私政策](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)。数据可能在您所在地区以外处理；使用前请核对您的账户条款。

macOS 1.3.1 中选择 OpenRouter 或 Google Gemini 时，也适用相应接收方的政策。OpenRouter 会根据所选模型及路由设置将请求转交模型提供商，免费路由的接收方可能变化，适用 [OpenRouter 隐私政策](https://openrouter.ai/privacy) 及其[模型供应商政策](https://openrouter.ai/providers)。Gemini 适用 [Gemini API 条款](https://ai.google.dev/gemini-api/terms) 和 [Google 隐私政策](https://policies.google.com/privacy)。

AI 费用、额度和可用性由服务商决定。AI 回答可能不准确。不要提交您无权分享的文档或敏感内容。

### 保留、删除及选择

本地记录会保留到您删除为止。当前可在“历史”中删除所选查询和追问，在设置中删除所选服务的 Key；删除 Key 不会删除其他服务的 Key。要清除全部本地记录，可先退出应用、备份需要的内容，再通过 Finder 删除相应数据目录：商店版为 `~/Library/Containers/org.deepreader.macos/Data/Library/Application Support/DeepReader/`，站外版为上述 DeepReader 目录。文件授权书签也会随目录删除；原始文档不会因此删除。卸载应用本身不保证删除记录或钥匙串条目。归档文件、导出文件、备份和同步副本需要在各自位置另行管理。

停止使用 AI 功能可停止新的 AI 请求。删除本地记录或 Key 不会删除服务商已经收到的数据；相应请求应联系服务商。DeepReader 维护者无法从您的本机远程取回或删除阅读资料。

### 联系与变更

运营者为 Baoshi Sun，隐私问题请发送至 [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com)。您主动联系时，运营者会收到您发送的邮箱地址、消息和附件，用于处理请求；不要发送 API Key 或不必要的私人资料。一般、不含个人资料的问题可使用 [GitHub Issues](https://github.com/BaoshiSun/DeepReader/issues)。不要在公开 Issue 中提交 Key、私人文档、阅读历史或身份资料。

版本功能或处理方式变化时将更新本政策，并注明生效日期。

## macOS — English

### Local reading and storage

DeepReader reads documents and ebooks without a DeepReader account. Reading, search, ratings, reading status, book lists and local archiving do not require AI calls. The current app has no embedded advertising or analytics SDK and no developer-operated cloud sync. It does not send your reading library to the DeepReader maintainer.

The app stores settings, document paths and titles, ratings, reading dates and status, archive paths, ebook highlights, and successful explanations, follow-ups and summaries locally. Lookup records may include selected text, context, answers, timestamps, page numbers, provider and model names. Archiving copies the original-format file to your chosen location. Exports can contain filenames and source text.

The Mac App Store build stores data and file-access bookmarks in its system-assigned app container, without automatically importing the direct version’s data. The current direct-distribution build stores these records in `~/Library/Application Support/DeepReader/`. The app does not separately encrypt these files. OS account permissions and any disk encryption you enable provide protection. Backups, synced folders, exports and archives can create additional copies. Provider API keys are stored separately in macOS Keychain and are sent to the selected provider to authenticate requests; they are not stored in settings JSON or public release packages.

### AI requests and recipients

Starting with macOS 1.3.1, you can choose “Allow and remember, send” for the current provider and full endpoint. This covers later explicitly requested explanations, follow-ups, document summaries and reading-history summaries. Permission is stored locally across restarts and can be revoked in Setup. You can also allow only the current operation or cancel. New recipients require consent; earlier one-time permissions are not automatically upgraded.

The older 1.2.1 (5) store build asks for each operation. macOS 1.3.1 asks when the current recipient has not been authorized, naming the provider, model and content scope. Cancel keeps reading offline. The earlier 1.2.1 GitHub preview sends requests when an AI feature is invoked, without this new per-operation dialog. Requests go directly from your Mac to your selected provider, without a DeepReader-operated relay. Explanations send the selection and nearby context. Follow-ups add the question and conversation. Document summaries send extractable full text, with intermediate notes used to combine long sections. Period summaries send selected saved passages, answers, timestamps and record titles.

The app does not upload document binaries or deliberately insert full local directory paths into prompts. Text can itself contain personal information, and period-summary titles may include filenames. Providers also receive network information such as your IP address and request time. DeepSeek may associate requests with the account owning the API key, retain usage and technical diagnostic logs, and infer coarse location from IP addresses for security and abuse prevention; DeepReader does not request GPS location. Provider processing may include functionality, analytics and service improvement, including model training permitted by its policy. The store privacy label therefore declares user content, user identifiers, usage data, diagnostic data and coarse location. Local reading does not automatically upload these data.

The older 1.2.1 (5) store build supports only DeepSeek. macOS 1.3.1 supports the providers and custom compatible endpoints listed at the beginning of this policy. Retention, logging, training use, international processing and deletion depend on DeepSeek's applicable terms and account settings. DeepReader does not promise zero retention or no training use. Read the [DeepSeek privacy policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html). Processing may occur outside your country. Provider fees and quotas apply. AI answers may be inaccurate; share only content you are authorized to disclose.

OpenRouter and Google Gemini are also available in macOS 1.3.1. OpenRouter routes requests to model providers; recipients and data handling can vary. See the [OpenRouter privacy policy](https://openrouter.ai/privacy) and [model-provider policies](https://openrouter.ai/providers). The Gemini option is governed by the [Gemini API terms](https://ai.google.dev/gemini-api/terms) and [Google privacy policy](https://policies.google.com/privacy).

### Retention and deletion

Local records remain until you delete them. History allows deletion of a selected lookup and its follow-ups. Setup allows deletion of the selected provider's key; other providers' keys are separate. To remove all local records, quit the app, back up anything you need, then remove its application-support directory in Finder. The store edition uses `~/Library/Containers/org.deepreader.macos/Data/Library/Application Support/DeepReader/`; the direct edition uses the path above. This also removes file-access bookmarks, but does not remove original documents. Uninstalling the app alone does not guarantee removal of records or Keychain items. Manage archive copies, exports and backups separately.

Stopping AI use stops new AI requests. Local deletion does not remove information already received by a provider; contact that provider for its deletion process. The maintainer cannot remotely retrieve or delete your local library.

### Contact and updates

The operator is Baoshi Sun. Contact [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com) for privacy questions. If you contact the operator, your sender address, message and any attachments are received to handle your request; do not send API keys or unnecessary private material. Non-sensitive support questions may be posted in the project's GitHub Issues. Never post credentials, private documents or reading records publicly. This policy will be updated when relevant practices change.


## iOS / iPadOS — 中文

iOS 版不要求创建 DeepReader 账户，没有广告、分析统计 SDK 或自有云同步。本地阅读不发送内容。应用将通过“文件”导入的 PDF、EPUB、TXT 和 Markdown 复制到本机应用容器；原文件不变。容器内保存文档副本、标题、评分、读完状态、阅读位置、文字高亮、语言设置、发送授权和成功的 AI 历史。历史可包含选文、语境、问题、回答、页码、时间、服务商和模型。操作系统备份可能包含这些数据；这不代表应用提供跨设备同步。

API Key 单独保存在 iOS 钥匙串（仅限本设备的可访问性设置），不写入书库 JSON、源码或发行包。发起 AI 请求时，Key 直接发送给所选服务商和接口地址进行认证，不经过 DeepReader 服务器。iOS 1.1.0 按服务商及接口地址隔离保存 Key；模型 ID、接口地址和授权保存在本机设置中。

选中文字只打开阅读浮窗，不触发网络请求。首次点击解释、追问或全文总结时，应用在浮窗内说明接收方及数据范围；选择“同意并记住，发送”后，将在本机保存授权。iOS 1.1.0 的授权绑定服务商及完整接口地址，换接收方需重新授权，旧版全局授权不自动沿用。之后只有您主动点击相应 AI 操作才发送，不再逐次询问。可在“设置 → 数据与隐私”撤销授权；撤销不影响本地阅读，也不能收回已发送的数据。取消首次授权不发送任何内容。

解释发送选文和附近语境；追问还发送原选文、语境、先前回答和新问题；全文总结发送可提取全文，长文会分段处理并发送中间摘要合并。不上传原始文档二进制文件，不自动附带设备上的完整文件路径，不支持日／周／月总结。

iOS 1.1.0 的接收方可为本政策开头列出的服务商及自定义兼容接口，旧 1.0.0 仅为 DeepSeek（api.deepseek.com）。所选接收方及其下游服务的账户关联、网络与使用日志、IP 推断的粗略位置、保留、训练和跨境处理由其政策及账户设置决定，详见开头的多模型说明。应用不请求 GPS 位置，不使用广告跟踪。API 费用和额度由用户的服务商账户承担。

可在书库长按删除导入副本，在历史列表左滑删除记录，在设置中移除 Key。删除书籍副本不会删除原文件或既有历史；需分别删除。卸载应用会移除本机应用容器，但系统备份和导出副本应单独管理；卸载不保证删除钥匙串 Key，建议先在应用中移除。服务商已接收的数据需联系服务商申请删除。通过系统分享功能导出的文件和回答由您选择的目标应用处理。

运营者为 Baoshi Sun，联系 [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com)。主动发送的邮件和附件仅用于处理您的支持请求；请勿发送 API Key 或无关私人资料。

## iOS / iPadOS — English

The iOS edition has no DeepReader account, advertising, analytics SDK or developer-operated cloud sync. Local reading sends no content. PDF, EPUB, TXT and Markdown files imported from Files are copied into the app container; originals remain unchanged. Local data includes document copies, titles, ratings, finished status, reading position, highlights, language settings, sharing permission and successful AI history. History may include selections, context, questions, answers, page numbers, timestamps, provider and model. OS backups may include these data; the app does not provide cross-device sync.

Your API key is stored separately in iOS Keychain with ThisDeviceOnly accessibility, never in library JSON, source code or distribution packages. Requests send the key directly to the selected provider and endpoint for authentication, without a developer-operated relay. iOS 1.1.0 isolates credentials by provider and endpoint; model IDs, endpoints and sharing permission are stored in local settings.

Selecting text only opens the floating assistant. Before the first Explain, Follow-up or Summary request, an inline disclosure names the recipient and data scope. Tapping Allow, remember and send stores permission locally. In iOS 1.1.0, permission is bound to the provider and full endpoint; changed recipients require new permission, and older global consent is not reused. Subsequent requests occur only when you tap an AI action, without repeated prompts. Revoke permission in Settings → Data and privacy; this preserves local reading and cannot recall data already sent. Cancelling first-use permission sends nothing.

Explanations send selected text and nearby context. Follow-ups add the original context, previous answer and new question. Summaries send extractable full text; long documents are split and intermediate notes are sent for merging. The app does not upload document binaries or automatically append full device file paths. The iOS edition has no daily, weekly or monthly summary feature.

iOS 1.1.0 supports the providers and custom compatible endpoints listed at the beginning of this policy; the older 1.0.0 build uses only DeepSeek (api.deepseek.com). Account linkage, network/usage logs, IP-derived coarse location, retention, training and international processing depend on the actual recipient and its downstream providers, as explained in the multiple-provider section. The app does not request GPS location or use advertising tracking. Provider fees and quotas belong to your provider account.

Long-press a library item to delete its imported copy, swipe in History to delete records, and remove the key in Settings. Deleting a book copy leaves the original file and existing history intact; delete them separately if desired. Uninstalling removes the local app container, but backups and exports require separate management. Uninstalling does not guarantee Keychain deletion; remove the key in-app first. Contact the provider to request deletion of data it already received. System sharing sends exported documents or answers to the destination app you choose.

The operator is Baoshi Sun: [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com). Emails and attachments you voluntarily send are used to handle your support request. Do not send API keys or unnecessary private information.
