# iOS 1.1.0 (4) — App Review Notes

DeepReader iOS 1.1.0 (4) is a free reader with bundled, fully on-device Qwen AI. It consolidates the offline build 3 and removes the old remote AI, credential, purchase and advertising code from the iOS app. No question quota or subscription applies.

1. Guidelines 3.1.1 and 5
No API-key entry, remote AI provider, custom endpoint, paid unlock, credit purchase or external payment is available. No credentials are required or bundled. Explanations and follow-ups use Qwen3 0.6B Q4_K_M through llama.cpp on device. There is no AI server, remote fallback, web search or runtime model download. ChatGPT/OpenAI and Claude functionality is unavailable. The app and all included features are free, without ads. The earlier question-credit IAP is not used or submitted with this version. Store metadata describes only offline iOS features.

2. Purpose and audience
A reader for individuals, students and researchers to understand their own documents through local reading, highlights, explanations and history beside the text. No hosted bookstore or enterprise-only access.

3. Setup and features
No login is needed. In an empty Library, tap Read a sample / 打开示例文章, or import PDF, EPUB, TXT or Markdown from Files. Select a short sentence and tap Explain in the reading assistant. Ask follow-ups below the answer. Settings switches English/Chinese and Book only / General knowledge; neither mode browses the web. Wide screens have an adjustable sidebar or floating panel; narrow screens use a draggable/collapsible floating panel. Answers stay in local History. Import preserves originals. Full-document summaries, DRM and OCR are unavailable.
AI answers may be inaccurate or incomplete. Warnings appear above answer controls, in Settings and in both store descriptions. Short input/output limits protect device memory and response time, not a paid quota. Initial model setup takes several seconds. Reading and AI work without Internet access.

4. Libraries and data
Bundled Qwen3 0.6B (Apache 2.0), llama.cpp (MIT), ZIPFoundation (MIT), Apple SwiftUI/UIKit/PDFKit/Files. Licenses are in Settings. No developer backend, advertising or analytics SDK is included. Books and history stay in the app container and may be included in system backups. Sharing/export and support links are user initiated. The shared privacy policy distinguishes offline iOS from the separate macOS edition.

5. QA and regions
On 2026-10-19, two tests passed on a physical iPhone 14 Pro running iOS 26.6.2 using the separately signed build-4 local development variant with the same source/engine: real explanations, follow-up, cancellation, history and legacy-settings compatibility. Sixteen simulator tests passed, including document import, EPUB/PDF safety and iPhone/iPad layouts. The store archive includes the verified model and matching llama symbols.
The same offline features are offered in all 175 selected storefronts, including mainland China. No regional remote service or provider account is needed.
Attached video: DeepReader-Local-Qwen-iPhone14Pro-2026-10-15.mp4 (1m55s). It shows launch, reading, Qwen answers, history, settings/language and the floating assistant on a physical iPhone 14 Pro, iOS 26.6.2. It is an earlier local development variant, not the exact build-4 binary. The same offline workflow remains; build 4 uses single-column library rows and clearer free/no-ads wording. Tester-imported documents in the video are not bundled or supplied by the app.

6. Content and rights
No regulated professional service, public posting, messaging or account creation. Users import their own documents; Reading Garden is original project content. No third-party catalog is supplied. Source is AGPL-3.0-or-later; model/library licenses and icon attribution are bundled. This is an independent reader.
