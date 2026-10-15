# iOS 1.1.0 (3) — App Review Notes

DeepReader iOS 1.1.0 (3) replaces the API-based build 2 with fully on-device AI.

1. Guidelines 3.1.1 and 5
No API-key entry, remote AI provider, custom endpoint, paid AI unlock, subscription, credit purchase or external payment is available in this iOS build. No API credentials are required or bundled. All explanations and follow-ups use the bundled Qwen3 0.6B Q4_K_M model through llama.cpp, on the device. There is no AI server, remote fallback, web search or runtime model download. ChatGPT/OpenAI and Claude functionality is unavailable. The app and included features are free. The previously prepared question-credit IAP is not used or submitted with this version. The iOS store metadata now describes only the offline edition.

2. Purpose and audience
A document reader for individuals, students and researchers to understand their own documents using local reading, highlights, explanations and history beside the text. No hosted bookstore or enterprise-only access.

3. Setup and features
No account, login or credentials are needed. In an empty Library, tap Read a sample / 打开示例文章, or import PDF, EPUB, TXT or Markdown from Files. Select a short sentence, open the reading assistant and tap Explain. Ask follow-ups below the answer. Settings switches English/Chinese and Book only / General knowledge; neither mode browses the web. Wide screens support an adjustable sidebar or floating panel. Narrow screens use a draggable/collapsible floating panel. Answers stay in local History. Import preserves original files. Full-document summaries, DRM and OCR are unavailable in this edition.
AI answers may be inaccurate or incomplete: the warning appears above the answer controls, in Settings and in both store descriptions. Short input/output limits apply. Initial model setup may take several seconds. The main reading and AI features work without Internet access.

4. Libraries and data
Bundled Qwen3 0.6B (Apache 2.0), llama.cpp (MIT), ZIPFoundation (MIT), Apple SwiftUI/UIKit/PDFKit/Files. License texts are in Settings. No remote AI, developer backend, ads, analytics or tracking SDK. Books and history stay in the app container; system backups may include them. Sharing/export and external support links are user initiated. The shared privacy policy distinguishes this offline iOS build from the separate macOS edition.

5. QA and regions
The offline engine and reading workflow were tested on a physical iPhone 14 Pro running iOS 26.6.2: real explanations, follow-ups, cancellation and history. Simulator QA covers the local inference path and iPhone/iPad layouts. The same offline functionality is provided in mainland China, Hong Kong, Macao, Taiwan, Saudi Arabia, UAE, Qatar, Kuwait, Bahrain and Oman, without a provider account or regional remote service.
New attachment: DeepReader-Local-Qwen-iPhone14Pro-2026-10-15.mp4 (1m55s), recorded on the physical iPhone 14 Pro, iOS 26.6.2. It shows launching DeepReader Local, reading, local Qwen explanations, history, settings/language and the floating assistant. This is the separately signed local development variant with the same offline engine, not the exact App Store build-3 binary. Build 3 adds finalized accuracy-warning wording and store/support metadata; minor wording differs in the recording. Documents shown were imported by the tester and are not bundled or supplied by the app. This replaces the old build-2 online-demo attachment.

6. Content and rights
No regulated professional service, public posting, messaging or account creation exists. Users import their own documents; Reading Garden is original project content. No third-party book catalog is included. Source is AGPL-3.0-or-later, with bundled model/library licenses and icon attribution. This is an independent reader.
