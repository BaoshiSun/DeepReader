# macOS 发行工具与账号开通后的操作

准备日期：2026-10-07。现有 1.2.1 预览版仍为 ad-hoc 签名；本次准备没有把旧附件变成已公证版本，也没有提交 Mac App Store 审核。

## 本机工具

`python3 macos/release_preflight.py` 检查工具、完整 Xcode、证书类别和商店文案长度。检查不会读取 Keychain 密钥内容，只查询可用签名身份的类别。`--json` 输出机器可读结果；`--strict` 在环境检查未齐时返回非零。环境全绿也不代表商店门槛已经完成。

本机有 Swift、Git、Python、codesign、hdiutil、notarytool 和 stapler；本次另安装 ShellCheck 0.11.0 和 Xcode 26.3（17C529，Apple Silicon），Xcode 位于 `/Applications/Xcode.app`。其官方 XIP 经 `pkgutil --check-signature` 确认为 Apple 签名。首次启动仍停留在 Xcode 和 Apple SDKs 许可协议，未代替维护者接受协议。按 [Apple 系统要求](https://developer.apple.com/xcode/system-requirements) 选择兼容 macOS 的版本；当前系统 15.7.4 支持表中列出的 Xcode 26.3。后续重新安装可从 [官方 Downloads](https://developer.apple.com/download/all/?q=Xcode%2026.3) 下载。本次没有升级操作系统。

将完整 Xcode 放入 Applications，首次启动完成它要求的组件安装和许可步骤。可先只安装 macOS 开发所需内容。要只在当前终端选择开发目录而不改变全局设置：

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
python3 macos/release_preflight.py
```

安装名称不同则调整路径。再次核对 [Apple 当前上传要求](https://developer.apple.com/news/upcoming-requirements/)。XCTest 由完整 Xcode 提供；仅 Command Line Tools 可构建应用，但当前机器不能运行既有 XCTest 套件。

## 身份与凭据：账号审核通过后

1. 在 Xcode → Settings → Accounts 登录注册时的 Apple 账号，确认团队已激活。
2. 在账号管理或 Apple 开发者后台创建 Developer ID Application 证书及本机私钥，用于 GitHub／站外发行。App Store 构建另外使用 Apple Distribution／对应 Mac 商店签名与描述文件。
3. 在终端执行 `security find-identity -v -p codesigning`，找到实际的 `Developer ID Application: … (TEAMID)` 身份。不要导出私钥到仓库。
4. 如要使用公证脚本，运行交互式凭据保存命令，在 Apple 工具提示时自行输入 Apple ID、Team ID 和应用专用密码：

```sh
xcrun notarytool store-credentials DeepReader-notary
```

凭据保存在本机 Keychain。脚本只接收 profile 名称，不接收明文密码。应用专用密码应在 Apple 账号网站自行创建；不要发送到聊天、Issue、终端命令参数或 GitHub。也可使用 Apple 支持的 App Store Connect API 凭据流程，但本准备包没有创建或保存此类密钥。

## 构建待签名应用

在干净、已提交的源码上运行原有构建脚本，使应用内对应源码和 SOURCE-COMMIT 一致：

```sh
python3 tools/public_release.py --check-tracked
python3 macos/Tests/make_format_fixtures.py --upstream
(cd macos && swift test)
bash macos/build.sh
```

`build.sh` 输出 ad-hoc 通用 ZIP/DMG 及启动测试结果。它不是正式签名步骤。以下把 ZIP 解压到新的、被 Git 忽略的目录（版本名按实际输出修改）：

```sh
mkdir -p artifacts/developer-id-input
ditto -x -k macos/dist/DeepReader-v1.2.1-macos-universal.zip artifacts/developer-id-input
```

确认真实版本已包含所需变更，再继续；不要把旧版 UI 和新版说明混在一起。

## 仅签名并打包：不上传 Apple

```sh
bash macos/distribute.sh \
  --app artifacts/developer-id-input/DeepReader.app \
  --identity 'Developer ID Application: YOUR LEGAL NAME (YOURTEAMID)' \
  --output artifacts/developer-id-signed
```

替换身份为本机已有证书的完整名称。脚本复制应用，启用 Hardened Runtime 和安全时间戳，生成签名 DMG、ZIP、对应源码和校验文件。不会覆盖输入应用或已有输出目录。输出中的 `RESULT.txt` 明确写明“尚未公证”。

脚本针对当前只有一个主可执行文件的 DeepReader bundle；今后加入嵌套 helper、framework 或插件时，须先补上由内向外签名及相应测试，不能盲目用 `codesign --deep` 签名掩盖问题。

## 签名并向 Apple 公证

只有加入 `--notarize` 才会把应用、嵌入源码和许可证随 DMG 上传 Apple：

```sh
bash macos/distribute.sh \
  --app artifacts/developer-id-input/DeepReader.app \
  --identity 'Developer ID Application: YOUR LEGAL NAME (YOURTEAMID)' \
  --output artifacts/developer-id-notarized \
  --notarize --profile DeepReader-notary
```

流程：签名应用和 DMG → 提交 DMG → 等待 JSON 状态 `Accepted` → 给本地应用及 DMG 装订票据 → 验证票据和 Gatekeeper → 将已装订的应用重新压缩为 ZIP → 最后生成 SHA-256。ZIP 本身不能装订；本脚本将票据放进 ZIP 内的应用。DMG 顶层已装订，内置应用可由系统验证。全过程会保留原始输入。

完成后检查 `RESULT.txt`、`notarization.json`、`signature.txt`、`SOURCE-COMMIT.txt` 和 `SHA256SUMS.txt`。在另一台或干净用户的 Mac 验证下载安装体验，检查签名后的 WebKit 阅读、钥匙串和数据访问；Hardened Runtime 下的运行验证仍需真实证书。真实 Apple 流程尚未在账号待审核阶段验证。

## 公证拒绝、超时或网络中断

失败时脚本不会生成“已公证”结果或继续发布。保留输出文件，不重复提交同一请求。查看 `notarization.json` 中的 submission ID；若没有返回 ID，通过以下历史查询找到已接收的请求：

```sh
xcrun notarytool history --keychain-profile DeepReader-notary
xcrun notarytool info SUBMISSION_ID --keychain-profile DeepReader-notary
xcrun notarytool log SUBMISSION_ID --keychain-profile DeepReader-notary artifacts/notary-log.json
```

待 `info` 明确为 Accepted 后，才可对该请求对应且未被修改的 `staging/DeepReader.app` 和 DMG 执行 `xcrun stapler staple`、`xcrun stapler validate`。重新生成 ZIP，再生成 SHA256SUMS。若是拒绝，先按日志修复并从新的构建／输出目录重做；不要手改状态文件或宣称通过。脚本不自动轮询后台未完成的请求或自动重新上传。

## 验证准备工具

```sh
shellcheck macos/distribute.sh
bash -n macos/distribute.sh
python3 -m unittest discover -s tests -p 'test_distribution.py' -v
python3 -m unittest discover -s tests -p 'test_release.py' -v
```

离线流程测试替身验证分支顺序、失败停止、输出隔离和防覆盖，不模拟 Apple 审核结论，也不验证真实证书。

## Mac App Store 是另一个构建出口

完成 [上架清单](../docs/app-store/readiness.md) 后，在完整 Xcode 创建 archive，验证 App Store 签名／沙盒／描述文件，再上传 App Store Connect 和 TestFlight。当前脚本有意拒绝使用商店证书，避免把 Developer ID DMG 当成商店安装包。

参考：[Developer ID](https://developer.apple.com/developer-id/)、[公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)、[macOS 分发签名](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/)。
