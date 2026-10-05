# DeepReader 1.0.0 开源许可核对

核对日期：**2026-10-05**。范围：当前 Windows x64 便携版、固定版本 SumatraPDF 3.6.1rel 上游源码、原生 AI 修改及打包脚本。

## 结论

**在保留许可与署名、明确标识修改、随分发提供完整对应源码的前提下，当前修改并以 DeepReader 名义开源分发的方式与核对到的上游许可要求相符。** 可以增加 AI 功能、改名、免费或收费分发；收费不会免除源码及再分发义务。不能把包含这些组件的整个阅读器改成只允许闭源使用的许可证，也不能只发布一个无对应源码入口的 EXE。

这是基于实际源码、发行材料及公开许可文本的工程核对，不是法律意见或全面法律合规认证。未审查 DeepReader 商标是否可注册、全部历史贡献的权利链、各地区法律或模型服务条款。

## 实际许可构成

[SumatraPDF 3.6.1rel 的 AUTHORS](https://github.com/sumatrapdfreader/sumatrapdf/blob/3.6.1rel/AUTHORS) 明确写明：大部分 src 代码为 GPLv3，部分 utils / mui 代码为 BSD；由于 MuPDF，AGPLv3 第 13 条也适用于 SumatraPDF。应按固定版本文件判断，不能仅以仓库首页的单个许可证标签概括。

| 部分 | 核对依据 | 当前处理 |
| --- | --- | --- |
| SumatraPDF 主体 | 上游 COPYING：GPLv3 | 保留原许可与版权；发布包根目录提供 LICENSE-GPL-3.0.txt |
| utils / mui 等 BSD 部分 | 上游 COPYING.BSD、各文件头 | 保留原 BSD 文本，不改为独占的 AGPL 许可 |
| MuPDF、jbig2dec 等 | mupdf/COPYING、ext/jbig2dec/COPYING | 保留 AGPL 原文；组合分发适用 GPL / AGPL 的兼容条款 |
| DeepReader 原创增量 | 根 LICENSE、LICENSE-AGPL-3.0.txt、原生源文件 | AGPL-3.0-or-later；不声称重新许可上游代码 |
| 其余内嵌库、字体、图标 | AUTHORS 索引以及各组件文件中的原始声明 | 完整原始源码及声明随上游归档保留；发布根目录另列第三方说明 |
| 上游应用图标 | AUTHORS 指定 Alex、CC BY 3.0 | 改为绿色；明确标注原作者、改编日期、许可链接，源图与 ICO 随包提供 |
| WebView2 Loader SDK 1.0.992.28 | 锁定包的 LICENSE.txt | 文本为三条款 BSD 风格授权；原文作为 WebView2-LICENSE.txt 附带；这不代表其他 WebView2 产品均采用相同许可 |
| 上游 UnRAR 备用解压库 | ext/unrar/license.txt；原 premake5.lua 静态链接项 | 存在禁止特定用途的限制，本版移除备用调用与链接项；不编译进 DeepReader |

## 关键要求与对应措施

1. **修改标识、版权与许可。** [GPLv3 第 4、5 条](https://www.gnu.org/licenses/gpl-3.0.html#section5)要求保留声明并标识修改及日期。`docs/MODIFICATIONS.md` 明确版本与日期；补丁给每个被修改的上游文件加入注明 DeepReader 的日期行，不移除原文件头。
2. **完整对应源码。** [GPLv3 第 1、6 条](https://www.gnu.org/licenses/gpl-3.0.html#section6)涵盖生成及修改程序所需的源码和相关构建脚本。当前 win64 ZIP 包含固定版本完整上游归档、所有新增代码、补丁、构建与下载校验脚本，不仅是一个上游仓库链接。`prepare-source.py` 优先使用包内 `source/upstream/` 归档。通用编译工具另行下载；用户无需取得开发者密钥才能构建程序。
3. **界面中的法律声明。** [GPLv3 第 0、5(d) 条](https://www.gnu.org/licenses/gpl-3.0.html#section0)涉及交互界面的法律提示。DeepReader 的“帮助 → 关于 DeepReader”保留上游作者入口，并列出独立修改版、修改日期、版权、无担保、再分发许可、GPL / AGPL 查看链接和包内源码位置。完整许可亦在发布包内，可离线查看。
4. **GPL 与 AGPL 组合。** [GPLv3 第 13 条](https://www.gnu.org/licenses/gpl-3.0.html#section13)及 [AGPLv3 第 13 条](https://www.gnu.org/licenses/agpl-3.0.html#section13)允许相应组合，各部分原许可保留，并适用有关网络交互的要求。不能把“使用 GPL 上游”理解成可以忽略 MuPDF 的 AGPL 条款。
5. **当前 AI API 模式。** 此版为用户在本机运行的客户端，通过 HTTPS 请求所选模型服务；并未部署供远程用户交互的 DeepReader 服务。按 [GNU 关于 AGPL 网络交互及客户端的 FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#AGPLv3InteractingRemotely)，不能仅因为客户端联网就推断必须公开第三方模型权重或用户 API Key。若以后把修改后的阅读器逻辑作为网络服务供他人使用，应重新核对 AGPL 第 13 条并提供相应源码入口。
6. **图标署名。** 当前图标改编自上游应用图标，2026-10-05 改为绿色。保留 Alex 署名及 [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/) 链接，注明改编并以同一许可提供改编图标；其他图标作者见 THIRD-PARTY-NOTICES 与上游 AUTHORS。软件改名不会消除图标署名义务，也不代表获得商标授权。

## 对当前发布材料的修正

此次核对发现了上游摘要未完整反映的 **UnRAR** 问题：3.6.1rel 的构建脚本会将其静态链接进阅读器。其 [原始许可](https://github.com/sumatrapdfreader/sumatrapdf/blob/3.6.1rel/ext/unrar/license.txt)限制特定用途；[Fedora 的许可评估](https://fedoraproject.org/wiki/Licensing:Unrar)将其归为非自由、GPL 不兼容许可。本核对据此未将“上游已经这样发布”当作兼容性证明。

DeepReader 的补丁移除了 UnRAR 备用函数实现及所有相关链接项，仍使用 LGPL unarr；部分依赖备用路径的 RAR / CBR 文件会失去支持。完整上游归档保持原样以供校验，其中未使用的 UnRAR 是单独保留原许可的材料，不属于 DeepReader 已链接程序，也不能宣称它已变成 AGPL 代码。这次结论针对修正后的 DeepReader 构建，不为以前构建作同样保证。

- 产品统一命名 DeepReader，版本 1.0.0，明确独立于官方 SumatraPDF。
- 补齐修改日期、界面法律提示、源码位置，以及原生与上游许可边界。
- 将第三方说明完整复制到运行包，增加应用图标署名，保留 BSD、GPL、AGPL、WebView2 授权原文和上游 AUTHORS。
- 补充 FreeType Team 的二进制分发署名；剔除具有用途限制的 UnRAR 备用链接。
- win64 包按明确清单收录完整对应源码；源码 ZIP 为增量开发包，依赖锁定上游下载，本身不能替代 win64 包里的完整对应源码。
- 分发物排除个人 API 配置、历史与文件打开记录。开源代码不要求公开开发者或使用者的服务凭据。

## 以后发布时仍需满足

使用打包脚本生成的**完整 win64 ZIP**，或另行在同一下载位置明确提供该版本完整对应源码；不要单独上传 EXE 后只链接当前上游最新版。新增或升级组件时重新核对其授权，更新修改记录，并确保构建脚本与发布二进制对应。

公开发行使用 [DeepReader 源码仓库](https://github.com/BaoshiSun/DeepReader)及对应版本的 [Release 下载页](https://github.com/BaoshiSun/DeepReader/releases/tag/v1.0.0)。发布前应核实下载入口可访问、版本标签与源码一致，并为二进制附件保留完整对应源码。
