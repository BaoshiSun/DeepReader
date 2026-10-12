# 制作公开版本

只发布源码清单和生成的 ZIP。不要上传整个开发目录或已经使用过的阅读器目录。

## 源码

在源码根目录执行：

```powershell
python -m unittest discover -s tests -p test_release.py -v
python tools/public_release.py --source-zip
```

输出 `DeepReader-v1.2.0-source.zip`，包含 `tools/public_release.py` 明确列出的源文件及 SHA-256 清单。源码包很小；上游完整源码和编译工具按锁定 URL 与 SHA-256 下载。

若将已有开发目录发布到 GitHub，建议解压该源码包到一个新的空目录，再初始化 Git。这样旧版本交付文件、个人配置、阅读历史、日志、快捷方式和本地 Git 辅助快照都不会进入公开提交。使用 GitHub 的 noreply 邮箱提交，可避免将私人邮箱写进公开提交记录。

## Windows 便携包

```powershell
./native/build-native.ps1 -Prepare
python -m pip install -r requirements-build.txt
./native/test-core.ps1
./native/test-native.ps1
python native/package-native.py
```

输出 `DeepReader-v1.2.0-win64.zip`。打包脚本只接受明确列出的文件，使用干净阅读器设置，包含完整对应上游源码及许可。它不会复制旧 API Key；即使本机交付目录已有用户配置，ZIP 也不会包含这些文件。

发布新版本时，创建对应提交的版本标签和 Release，上传该版本生成的 ZIP 与 SHA-256 校验文件，并更新 README 下载入口。1.2.0 使用标签 `v1.2.0`；保留旧版本 Release。修改源码或本地打包不会自动更新 GitHub 上的附件。

公开下载应使用 GitHub Release 附件，避免将约 84 MB 的二进制及上游源码归档放入 Git 仓库。软件版本号位于 `tools/public_release.py`；发布新版本时同时更新使用说明与本文档。

## macOS 测试版

正式签名和公证准备见 [macOS 发行工具](../macos/DISTRIBUTION.md)；商店渠道的独立准备材料见 [App Store 准备包](app-store/README.md)。

macOS 的版本号位于 `macos/Info.plist`；Windows 版本号独立保留。macOS 1.2.1 使用标签 `v1.2.1-macos`，发布为 Pre-release。

在 Mac 上先运行 `python3 macos/Tests/make_format_fixtures.py --upstream`，再进入 `macos/` 执行 `swift test`。确认公开源码检查通过并提交源码后，在仓库根目录运行 `bash macos/build.sh`。构建会生成 Apple Silicon / Intel 通用应用并执行离线启动测试。

将 `macos/dist/` 中的 DMG、universal ZIP、macos-source ZIP 和 `SHA256SUMS.txt` 上传到指向同一源码提交的 GitHub Release。检查应用内 `SOURCE-COMMIT.txt` 和 `Source.zip` 与标签一致。发布说明须标明最低 macOS 版本、实际测试平台，以及尚未进行 Developer ID 签名和 Apple 公证。不要将个人阅读数据或本地测试样本上传为发行附件。

## 发布前复核

- 源码检查和相关原生测试通过，ZIP 通过完整性与密钥扫描。
- 公开压缩包中没有 `AIReader.json`、`DeepSeek.json`、`config.json`、`AIHistory/`、`BookLibrary/`、归档 PDF 或真实打开文件的设置。
- 说明默认 DeepSeek 官方 API 需要自己的 Key 并按量计费；可选 OpenRouter 免费路由也需要独立账号和 Key。没有预置共享 Key，也没有免注册服务。
- 附带 AGPL 文本、上游作者、第三方许可、构建步骤和对应源码。
- 保留 GPL 与 BSD 文本、图标作者署名、MODIFICATIONS.txt 与许可核对报告；“关于 DeepReader”须能显示修改日期及源码位置。
- 单独的 source.zip 是增量开发包。二进制发行使用包含完整对应源码的 win64 ZIP，不用上游最新版链接替代该版本源码。
- 构建时保留 DeepReader 的 UnRAR 排除补丁；原生阅读器的链接依赖不能包含 unrar.lib，重建的 utils.lib 不能包含 UnRAR API 符号。不要重新启用备用路径而跳过许可评估。

扫描器检查常见令牌、DPAPI 密文、非空配置密钥字段、个人 Windows 路径及不应分发的文件名；不是覆盖所有秘密格式的保证。手动复核仍是发布步骤的一部分。
