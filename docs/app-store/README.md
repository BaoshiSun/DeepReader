# DeepReader macOS 上架准备包

更新日期：2026-10-10。维护者已告知个人开发者会员获批；本机 Xcode 已登录 Apple 账号，当前仍没有有效发布签名身份。证书创建入口已加载可用，正在等待创建持久签名凭据的明确授权。已增加商店构建工程并通过未签名通用归档，尚未上传 Apple。

**这是准备材料，不是已经符合商店要求的发行版。** 不在这里填写 Apple 密码、应用专用密码、证书私钥、API Key 或审核专用凭据。

商店工程与本轮验证：[macos/AppStore/README.md](../../macos/AppStore/README.md)。

## 已备齐的材料

| 文件 | 用途 | 状态 |
| --- | --- | --- |
| [listing.json](listing.json) | 中英文名称、副标题、宣传文本、介绍、关键词 | 可编辑草稿；名称可用性和分类待后台确认 |
| [privacy-policy.md](privacy-policy.md) | 按实际代码编写的中英文隐私政策 | 草稿；运营者、私密联系渠道、服务商条款待确认 |
| [review-notes.md](review-notes.md) | 英文审核说明、复现步骤和测试材料 | 提交模板；需补实际构建、联系人和审核访问方式 |
| [readiness.md](readiness.md) | 沙盒、隐私、许可、截图及真机验收清单 | 有未完成的工程项目，不能仅等待账号开通 |
| [../../macos/DISTRIBUTION.md](../../macos/DISTRIBUTION.md) | 工具安装、证书、公证和失败恢复 | 可执行流程；正式签名／公证待账号和证书 |
| [../../macos/release_preflight.py](../../macos/release_preflight.py) | 本机环境和文案长度检查 | 只读检查，不读取密钥，不登录 Apple |
| [../../macos/distribute.sh](../../macos/distribute.sh) | Developer ID 签名、DMG/ZIP、公证票据及校验 | 为站外发行准备，不用于商店提交 |

在仓库根目录运行：

```sh
python3 macos/release_preflight.py
python3 -m unittest discover -s tests -p 'test_distribution.py' -v
shellcheck macos/distribute.sh
```

检查程序始终列出人工／工程门槛，不会用“工具都存在”推断已可上架。新增文件已纳入公开源码清单。

## 账号等待期间与开通后的安排

现已加入沙盒文件书签、逐次 AI 明确同意、原生 Xcode 应用目标及文件元数据用途声明。27 项离线测试通过，本机沙盒 EPUB 打开、重启恢复和归档已验证。仍需完成正式身份签名测试、公开政策和商店信息，并复核开源许可与商店条款。

账号开通后：在本机 Xcode 登录个人开发者账号，核对 Team ID 和 Bundle ID，创建所需证书和描述文件。App Store 流程直接使用商店分发签名、TestFlight 和审核提交；Developer ID 公证是独立的站外发行流程，不是商店上架前置条件。正式的签名、公证、Apple 上传、付费设置和商店提交在本次准备工作中均未执行。

待维护者决定：

- 维护者已确认应用免费。继续按现有自带 API Key 功能准备；应用免费不代表服务商 API 免费。
- 上架国家／地区；涉及的当地要求需按实际选择确认。
- 商店显示的法定个人卖家姓名、审核联系人及私密支持邮箱。这些资料不应写入公开 Git 仓库。
- 隐私政策和支持页面的长期公开 URL；本地 Markdown 草稿不能直接填成隐私政策网址。
- 名称可用性、最终 Bundle ID（当前代码为 `org.deepreader.macos`）。标识变更需同步考虑钥匙串和数据迁移。

本次已从 Apple 官方下载、校验并将 Xcode 26.3（17C529，Apple Silicon）安装到 `/Applications/Xcode.app`，另安装 ShellCheck 0.11.0。截至 2026-10-10，Xcode 首次启动检查通过，应用 XCTest 已在本机补跑通过。系统目前为 macOS 15.7.4，Apple 兼容表列出 Xcode 26.3 支持 macOS 15.6+；这不等于它永久满足商店上传要求。提交当天重新检查兼容表和上传要求。本次未升级整个 macOS。

## 官方参考

- [Xcode 系统要求](https://developer.apple.com/xcode/system-requirements)
- [Apple 官方 Xcode 26.3 下载搜索](https://developer.apple.com/download/all/?q=Xcode%2026.3)
- [即将生效的提交要求](https://developer.apple.com/news/upcoming-requirements/)
- [App Store Connect 工作流程](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)
- [审核指南](https://developer.apple.com/app-store/review/guidelines/)
