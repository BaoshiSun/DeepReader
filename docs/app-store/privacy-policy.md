# DeepReader for macOS 隐私政策 / Privacy Policy

更新日期 / Updated: 2026-10-10。适用于 Mac App Store 版 1.2.1（构建 5 起）。运营者 / Operator: Baoshi Sun。隐私联系邮箱 / Privacy contact: [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com)。尚在准备送审，商店下载尚未开放。旧 GitHub 预览版的功能及数据位置有所不同，下文明确区分。

## 中文

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

不会上传文档二进制文件；程序不主动将本机完整目录路径加入提示词。但原文本身可能包含个人信息，周期总结中的标题可能来自文件名。服务商也会接收网络连接所必需的信息，例如 IP 地址和请求时间。

商店首发版仅提供 DeepSeek（`api.deepseek.com`），不提供 OpenRouter 或 Google Gemini 直连。DeepSeek 的保存期限、日志、训练使用、跨境处理和删除机制由其适用条款及账号设置决定；DeepReader 不承诺零保存或不用于训练。请阅读 [DeepSeek 隐私政策](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html)。数据可能在您所在地区以外处理；使用前请核对您的账户条款。

旧站外版另支持 OpenRouter 和 Google Gemini；商店内部候选构建 4 也支持 OpenRouter，但不会作为首发版本提交。OpenRouter 会根据所选模型及路由设置将请求转交模型提供商，免费路由的接收方可能变化，适用 [OpenRouter 隐私政策](https://openrouter.ai/privacy) 及其[模型供应商政策](https://openrouter.ai/providers)。旧站外版 Gemini 适用 [Gemini API 条款](https://ai.google.dev/gemini-api/terms) 和 [Google 隐私政策](https://policies.google.com/privacy)。

AI 费用、额度和可用性由服务商决定。AI 回答可能不准确。不要提交您无权分享的文档或敏感内容。

### 保留、删除及选择

本地记录会保留到您删除为止。当前可在“历史”中删除所选查询和追问，在设置中删除所选服务的 Key；删除 Key 不会删除其他服务的 Key。要清除全部本地记录，可先退出应用、备份需要的内容，再通过 Finder 删除相应数据目录：商店版为 `~/Library/Containers/org.deepreader.macos/Data/Library/Application Support/DeepReader/`，站外版为上述 DeepReader 目录。文件授权书签也会随目录删除；原始文档不会因此删除。卸载应用本身不保证删除记录或钥匙串条目。归档文件、导出文件、备份和同步副本需要在各自位置另行管理。

停止使用 AI 功能可停止新的 AI 请求。删除本地记录或 Key 不会删除服务商已经收到的数据；相应请求应联系服务商。DeepReader 维护者无法从您的本机远程取回或删除阅读资料。

### 联系与变更

运营者为 Baoshi Sun，隐私问题请发送至 [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com)。您主动联系时，运营者会收到您发送的邮箱地址、消息和附件，用于处理请求；不要发送 API Key 或不必要的私人资料。一般、不含个人资料的问题可使用 [GitHub Issues](https://github.com/BaoshiSun/DeepReader/issues)。不要在公开 Issue 中提交 Key、私人文档、阅读历史或身份资料。

版本功能或处理方式变化时将更新本政策，并注明生效日期。

## English

### Local reading and storage

DeepReader reads documents and ebooks without a DeepReader account. Reading, search, ratings, reading status, book lists and local archiving do not require AI calls. The current app has no embedded advertising or analytics SDK and no developer-operated cloud sync. It does not send your reading library to the DeepReader maintainer.

The app stores settings, document paths and titles, ratings, reading dates and status, archive paths, ebook highlights, and successful explanations, follow-ups and summaries locally. Lookup records may include selected text, context, answers, timestamps, page numbers, provider and model names. Archiving copies the original-format file to your chosen location. Exports can contain filenames and source text.

The Mac App Store build stores data and file-access bookmarks in its system-assigned app container, without automatically importing the direct version’s data. The current direct-distribution build stores these records in `~/Library/Application Support/DeepReader/`. The app does not separately encrypt these files. OS account permissions and any disk encryption you enable provide protection. Backups, synced folders, exports and archives can create additional copies. Provider API keys are stored separately in macOS Keychain and are sent to the selected provider to authenticate requests; they are not stored in settings JSON or public release packages.

### AI requests and recipients

The Mac App Store build asks for consent for each AI operation, naming the provider, model and content scope. Cancel keeps reading offline. The earlier 1.2.1 GitHub preview sends requests when an AI feature is invoked, without this new per-operation dialog. Requests go directly from your Mac to your selected provider, without a DeepReader-operated relay. Explanations send the selection and nearby context. Follow-ups add the question and conversation. Document summaries send extractable full text, with intermediate notes used to combine long sections. Period summaries send selected saved passages, answers, timestamps and record titles.

The app does not upload document binaries or deliberately insert full local directory paths into prompts. Text can itself contain personal information, and period-summary titles may include filenames. Providers also receive network information such as your IP address and request time.

The Mac App Store launch edition supports only DeepSeek (`api.deepseek.com`), with no OpenRouter or direct Google Gemini option. Retention, logging, training use, international processing and deletion depend on DeepSeek's applicable terms and account settings. DeepReader does not promise zero retention or no training use. Read the [DeepSeek privacy policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html). Processing may occur outside your country. Provider fees and quotas apply. AI answers may be inaccurate; share only content you are authorized to disclose.

The earlier direct-distribution edition also supports OpenRouter and Google Gemini. Internal store candidate build 4 supports OpenRouter but will not be submitted for launch. OpenRouter routes requests to model providers; recipients and data handling can vary. See the [OpenRouter privacy policy](https://openrouter.ai/privacy) and [model-provider policies](https://openrouter.ai/providers). The earlier direct-distribution Gemini option is governed by the [Gemini API terms](https://ai.google.dev/gemini-api/terms) and [Google privacy policy](https://policies.google.com/privacy).

### Retention and deletion

Local records remain until you delete them. History allows deletion of a selected lookup and its follow-ups. Setup allows deletion of the selected provider's key; other providers' keys are separate. To remove all local records, quit the app, back up anything you need, then remove its application-support directory in Finder. The store edition uses `~/Library/Containers/org.deepreader.macos/Data/Library/Application Support/DeepReader/`; the direct edition uses the path above. This also removes file-access bookmarks, but does not remove original documents. Uninstalling the app alone does not guarantee removal of records or Keychain items. Manage archive copies, exports and backups separately.

Stopping AI use stops new AI requests. Local deletion does not remove information already received by a provider; contact that provider for its deletion process. The maintainer cannot remotely retrieve or delete your local library.

### Contact and updates

The operator is Baoshi Sun. Contact [baoshi.sun@icloud.com](mailto:baoshi.sun@icloud.com) for privacy questions. If you contact the operator, your sender address, message and any attachments are received to handle your request; do not send API keys or unnecessary private material. Non-sensitive support questions may be posted in the project's GitHub Issues. Never post credentials, private documents or reading records publicly. This policy will be updated when relevant practices change.
