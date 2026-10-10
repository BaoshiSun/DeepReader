# DeepReader 隐私政策 / Privacy Policy

更新日期 / Updated: 2026-10-11。适用于 Mac App Store 版 1.2.1（构建 5 起），以及 iOS / iPadOS 版 1.0.0。运营者 / Operator: Baoshi Sun。隐私联系邮箱 / Privacy contact: [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com)。尚在准备送审，商店下载尚未开放。旧 GitHub 预览版的功能及数据位置有所不同，下文明确区分。

## macOS — 中文

### 本机阅读和保存

DeepReader 是文档与电子书阅读器，不要求创建 DeepReader 账户。打开、查找、评分、阅读状态、书单和本地归档不需要调用 AI。当前应用没有内置广告或分析统计 SDK，不将阅读库发送给 DeepReader 维护者，也不提供自有云同步。

应用在本机保存设置、文档路径和标题、评分、阅读状态和日期、归档路径、电子书高亮，以及成功的解释、追问与总结。解释记录可能包含选文、语境、回答、时间、页码、服务商和模型名称。归档会在您指定的位置另存原格式文件；导出的记录可能含文件名和原文。

商店版的数据位于系统分配的应用容器，另保存文件授权书签；不会自动导入站外版资料。当前站外版数据位于 `~/Library/Application Support/DeepReader/`。这些记录不由应用另行加密；操作系统账户权限及您启用的磁盘加密提供保护。系统备份、您选择的同步目录、手动导出和归档可能产生额外副本。

API Key 单独保存在 macOS 钥匙串，不写入设置 JSON 或公开发行包。发起 AI 请求时，所选服务商会接收该服务的 Key 用于身份验证。

### 何时向 AI 服务发送数据

商店版在每次 AI 操作发送前显示接收方、模型及内容范围，只有点击“同意并发送”才发送；取消仍可离线阅读。旧的 1.2.1 GitHub 预览版仅在主动触发 AI 操作时发送，尚无新增的逐次同意弹窗。数据直接由本机发送给所选服务的 API，而不是经过 DeepReader 自有服务器。

| 操作 | 发送内容 |
| --- | --- |
| 解释选文 | 选中的文字、附近语境及回答语言等指令 |
| 继续追问 | 当前问题、原选文与语境、已有对话 |
| 文件总结 | 可提取的全文；长文按段请求并发送中间摘要进行合并 |
| 日／周／月总结 | 所选时间范围的已保存选文、回答、记录时间和记录标题 |

不会上传文档二进制文件；程序不主动将本机完整目录路径加入提示词。但原文本身可能包含个人信息，周期总结中的标题可能来自文件名。服务商也会接收网络连接所必需的信息，例如 IP 地址和请求时间。DeepSeek 可能将请求与 API Key 所属账户关联，保留使用量和技术诊断日志，并根据 IP 推断粗略位置用于安全与防滥用；DeepReader 不请求 GPS 位置。服务商可能为功能提供、分析和改进服务处理数据，包括其政策允许的模型训练。商店隐私标签因此申报用户内容、用户标识、使用数据、诊断数据和粗略位置；不将本地阅读视为上述数据的自动上传。

商店首发版仅提供 DeepSeek（`api.deepseek.com`），不提供 OpenRouter 或 Google Gemini 直连。DeepSeek 的保存期限、日志、训练使用、跨境处理和删除机制由其适用条款及账号设置决定；DeepReader 不承诺零保存或不用于训练。请阅读 [DeepSeek 隐私政策](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)。数据可能在您所在地区以外处理；使用前请核对您的账户条款。

旧站外版另支持 OpenRouter 和 Google Gemini；商店内部候选构建 4 也支持 OpenRouter，但不会作为首发版本提交。OpenRouter 会根据所选模型及路由设置将请求转交模型提供商，免费路由的接收方可能变化，适用 [OpenRouter 隐私政策](https://openrouter.ai/privacy) 及其[模型供应商政策](https://openrouter.ai/providers)。旧站外版 Gemini 适用 [Gemini API 条款](https://ai.google.dev/gemini-api/terms) 和 [Google 隐私政策](https://policies.google.com/privacy)。

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

The Mac App Store build asks for consent for each AI operation, naming the provider, model and content scope. Cancel keeps reading offline. The earlier 1.2.1 GitHub preview sends requests when an AI feature is invoked, without this new per-operation dialog. Requests go directly from your Mac to your selected provider, without a DeepReader-operated relay. Explanations send the selection and nearby context. Follow-ups add the question and conversation. Document summaries send extractable full text, with intermediate notes used to combine long sections. Period summaries send selected saved passages, answers, timestamps and record titles.

The app does not upload document binaries or deliberately insert full local directory paths into prompts. Text can itself contain personal information, and period-summary titles may include filenames. Providers also receive network information such as your IP address and request time. DeepSeek may associate requests with the account owning the API key, retain usage and technical diagnostic logs, and infer coarse location from IP addresses for security and abuse prevention; DeepReader does not request GPS location. Provider processing may include functionality, analytics and service improvement, including model training permitted by its policy. The store privacy label therefore declares user content, user identifiers, usage data, diagnostic data and coarse location. Local reading does not automatically upload these data.

The Mac App Store launch edition supports only DeepSeek (`api.deepseek.com`), with no OpenRouter or direct Google Gemini option. Retention, logging, training use, international processing and deletion depend on DeepSeek's applicable terms and account settings. DeepReader does not promise zero retention or no training use. Read the [DeepSeek privacy policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html). Processing may occur outside your country. Provider fees and quotas apply. AI answers may be inaccurate; share only content you are authorized to disclose.

The earlier direct-distribution edition also supports OpenRouter and Google Gemini. Internal store candidate build 4 supports OpenRouter but will not be submitted for launch. OpenRouter routes requests to model providers; recipients and data handling can vary. See the [OpenRouter privacy policy](https://openrouter.ai/privacy) and [model-provider policies](https://openrouter.ai/providers). The earlier direct-distribution Gemini option is governed by the [Gemini API terms](https://ai.google.dev/gemini-api/terms) and [Google privacy policy](https://policies.google.com/privacy).

### Retention and deletion

Local records remain until you delete them. History allows deletion of a selected lookup and its follow-ups. Setup allows deletion of the selected provider's key; other providers' keys are separate. To remove all local records, quit the app, back up anything you need, then remove its application-support directory in Finder. The store edition uses `~/Library/Containers/org.deepreader.macos/Data/Library/Application Support/DeepReader/`; the direct edition uses the path above. This also removes file-access bookmarks, but does not remove original documents. Uninstalling the app alone does not guarantee removal of records or Keychain items. Manage archive copies, exports and backups separately.

Stopping AI use stops new AI requests. Local deletion does not remove information already received by a provider; contact that provider for its deletion process. The maintainer cannot remotely retrieve or delete your local library.

### Contact and updates

The operator is Baoshi Sun. Contact [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com) for privacy questions. If you contact the operator, your sender address, message and any attachments are received to handle your request; do not send API keys or unnecessary private material. Non-sensitive support questions may be posted in the project's GitHub Issues. Never post credentials, private documents or reading records publicly. This policy will be updated when relevant practices change.


## iOS / iPadOS — 中文

iOS 版不要求创建 DeepReader 账户，没有广告、分析统计 SDK 或自有云同步。本地阅读不发送内容。应用将通过“文件”导入的 PDF、EPUB、TXT 和 Markdown 复制到本机应用容器；原文件不变。容器内保存文档副本、标题、评分、读完状态、阅读位置、文字高亮、语言设置、发送授权和成功的 AI 历史。历史可包含选文、语境、问题、回答、页码、时间、服务商和模型。操作系统备份可能包含这些数据；这不代表应用提供跨设备同步。

API Key 单独保存在 iOS 钥匙串（仅限本设备的可访问性设置），不写入书库 JSON、源码或发行包。发起 AI 请求时，Key 直接发送给 DeepSeek 认证，不经过 DeepReader 服务器。

选中文字只打开阅读浮窗，不触发网络请求。首次点击解释、追问或全文总结时，应用在浮窗内说明接收方及数据范围；选择“同意并记住，发送”后，将在本机保存授权。之后只有您主动点击相应 AI 操作才发送，不再逐次询问。可在“设置 → 数据与隐私”撤销授权；撤销不影响本地阅读，也不能收回已发送的数据。取消首次授权不发送任何内容。

解释发送选文和附近语境；追问还发送原选文、语境、先前回答和新问题；全文总结发送可提取全文，长文会分段处理并发送中间摘要合并。不上传原始文档二进制文件，不自动附带设备上的完整文件路径，不支持日／周／月总结。

接收方仅为 DeepSeek（api.deepseek.com）。其账户关联、网络与使用日志、IP 推断的粗略位置、保留、训练及跨境处理规则与本政策 macOS 部分所述相同；应用不请求 GPS 位置，不使用广告跟踪。详见 [DeepSeek 隐私政策](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)。API 费用和额度由用户的 DeepSeek 账户承担。

可在书库长按删除导入副本，在历史列表左滑删除记录，在设置中移除 Key。删除书籍副本不会删除原文件或既有历史；需分别删除。卸载应用会移除本机应用容器，但系统备份和导出副本应单独管理；卸载不保证删除钥匙串 Key，建议先在应用中移除。服务商已接收的数据需联系服务商申请删除。通过系统分享功能导出的文件和回答由您选择的目标应用处理。

运营者为 Baoshi Sun，联系 [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com)。主动发送的邮件和附件仅用于处理您的支持请求；请勿发送 API Key 或无关私人资料。

## iOS / iPadOS — English

The iOS edition has no DeepReader account, advertising, analytics SDK or developer-operated cloud sync. Local reading sends no content. PDF, EPUB, TXT and Markdown files imported from Files are copied into the app container; originals remain unchanged. Local data includes document copies, titles, ratings, finished status, reading position, highlights, language settings, sharing permission and successful AI history. History may include selections, context, questions, answers, page numbers, timestamps, provider and model. OS backups may include these data; the app does not provide cross-device sync.

Your API key is stored separately in iOS Keychain with ThisDeviceOnly accessibility, never in library JSON, source code or distribution packages. Requests send the key directly to DeepSeek for authentication, without a developer-operated relay.

Selecting text only opens the floating assistant. Before the first Explain, Follow-up or Summary request, an inline disclosure names the recipient and data scope. Tapping Allow, remember and send stores permission locally. Subsequent requests occur only when you tap an AI action, without repeated prompts. Revoke permission in Settings → Data and privacy; this preserves local reading and cannot recall data already sent. Cancelling first-use permission sends nothing.

Explanations send selected text and nearby context. Follow-ups add the original context, previous answer and new question. Summaries send extractable full text; long documents are split and intermediate notes are sent for merging. The app does not upload document binaries or automatically append full device file paths. The iOS edition has no daily, weekly or monthly summary feature.

The only recipient is DeepSeek (api.deepseek.com). Account linkage, network/usage logs, IP-derived coarse location, retention, training and international processing follow the provider rules described in the macOS section above. The app does not request GPS location or use advertising tracking. See the [DeepSeek privacy policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html). Provider fees and quotas belong to your DeepSeek account.

Long-press a library item to delete its imported copy, swipe in History to delete records, and remove the key in Settings. Deleting a book copy leaves the original file and existing history intact; delete them separately if desired. Uninstalling removes the local app container, but backups and exports require separate management. Uninstalling does not guarantee Keychain deletion; remove the key in-app first. Contact the provider to request deletion of data it already received. System sharing sends exported documents or answers to the destination app you choose.

The operator is Baoshi Sun: [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com). Emails and attachments you voluntarily send are used to handle your support request. Do not send API keys or unnecessary private information.
