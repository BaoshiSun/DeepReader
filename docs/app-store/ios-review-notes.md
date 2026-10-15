# iOS 1.1.0 (3) — offline replacement review notes

DeepReader iOS 1.1.0 (3) replaces the API-based build 2 with fully on-device AI.

1. Changes addressing Guidelines 3.1.1 and 5
No API-key entry, remote model provider, custom endpoint, paid AI unlock, subscription, credit purchase or external payment is available in this iOS build. No API credentials are required or bundled. All AI explanations and follow-ups use the included Qwen3 0.6B Q4_K_M model through llama.cpp, on the device. There is no AI server, remote fallback, web search or model download at runtime. ChatGPT/OpenAI and Claude functionality is not available. iOS product descriptions and promotional text describe only the offline edition. The app and all included features are free. The previously prepared question-credit IAP is not used or submitted with this version.

2. Purpose and target audience
A document reader for individuals, students and researchers to understand their own documents. It combines local reading, highlights, explanations and saved history beside the source text. It is not enterprise-only and has no hosted bookstore or public feed.

3. Setup and main features
No account, sign-in or credentials are needed. In the empty Library tap Read a sample / 打开示例文章, or import PDF, EPUB, TXT or Markdown from Files. Select a short sentence, open the reading assistant and tap Explain. Ask a follow-up below the answer. Settings switches English/Chinese and Book only / General knowledge (no web browsing). Wide screens offer an adjustable sidebar; narrow screens use a draggable, collapsible floating panel. Successful answers are saved in History. Original files are not modified by import. Full-document summaries, DRM and OCR are not supported in this edition.
AI answers may be inaccurate or incomplete. This warning is visible above the answer controls, in Settings and in both store descriptions. The small model has short-input/output limits; first initialization can take several seconds. All main reading and AI features can be tested without Internet access.

4. Libraries, services and data
Qwen3 0.6B (Apache 2.0), llama.cpp (MIT), ZIPFoundation (MIT), Apple SwiftUI/UIKit/PDFKit/Files. No remote AI, developer backend, analytics, advertising or tracking SDK. License texts are bundled in Settings. Books and history stay in the app container; system backups may include them. Optional sharing/export and external support links are user initiated. The shared app privacy policy distinguishes this offline iOS build from the separate macOS edition.

5. QA and regional behavior
The offline engine and reading workflow have been tested on a physical iPhone 14 Pro running iOS 26.6.2, including real explanations, follow-ups, cancellation and history. Simulator QA also covers the local inference path and iPhone/iPad layouts. The same offline functionality is included in all selected storefronts: mainland China, Hong Kong, Macao, Taiwan, Saudi Arabia, UAE, Qatar, Kuwait, Bahrain and Oman. No provider account or regional remote service is needed.
The earlier build-2 video shows the superseded online edition; it is not a recording of build 3.

6. Content and rights
No regulated professional service, public posting, messaging or account creation exists. Users provide their own documents; the bundled Reading Garden sample is original project content. No third-party book catalog is included. Source is AGPL-3.0-or-later; model/library licenses and icon attribution are provided in the app. This is an independent reader.
