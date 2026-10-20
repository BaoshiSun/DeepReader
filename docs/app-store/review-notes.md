# macOS 1.3.1 (9) — App Review Notes

This submission replaces rejected macOS 1.3.1 (8) with a free, fully on-device Qwen reader. There are no paid features, ads, subscriptions, API keys, credits, external payments, accounts or remote AI services in this Mac App Store build.

1. Changes for Guidelines 3.1.1 and 5
The API provider/key settings, credential implementation, remote AI transport and question-credit/StoreKit code are excluded from the store build. OpenAI/ChatGPT, Claude and other remote-provider functionality is not available. No key, purchase, login or provider account unlocks anything. Explanations and follow-ups use bundled Qwen3 0.6B Q4_K_M through llama.cpp entirely on the Mac. No server, network fallback or model download is used. Store descriptions, promotional text and new screenshots describe this offline version. The same free functionality applies in all selected storefronts, including mainland China. No IAP product is submitted with this version.

2. Purpose and audience
A document and ebook reader for individuals, students and researchers to understand their own reading material, highlight passages and keep local answer history beside the text. No enterprise restriction, public posting, user accounts or hosted book catalog.

3. Testing the main features
No credentials are required. In Setup, click Read a sample / 打开示例文章 to open the original bundled Reading Garden text, or use Open to choose PDF, EPUB, TXT, Markdown or DRM-free MOBI/AZW3. Select a short sentence and press Command-Shift-D or Explain selection. Type a question below the answer and press Command-Return. Successful answers and follow-ups are saved in local History. The window button floats/docks the assistant; drag the sidebar divider to resize. Switch Chinese/English using the language button. Book only / Add general knowledge changes the answer scope, not Internet access. Rate books, mark them finished, export records or archive copies to a user-selected folder. PDF highlights can be saved; ebook highlights remain local.

AI answers may be inaccurate, incomplete or fabricated. Warnings appear in the assistant, Setup and both store descriptions. Qwen 0.6B is a small model for simple explanations, not authoritative professional advice. Input/output length limits protect responsiveness, not paid quotas. Full-document and period summaries are unavailable. The model is included in the roughly 500 MB app. Initial setup may take time; generation increases power use and warmth.

4. Dependencies, privacy and rights
Bundled Qwen3 0.6B (Apache 2.0), llama.cpp (MIT), libmobi (LGPL-3.0-or-later), Apple AppKit/SwiftUI/PDFKit/WebKit and system archive APIs. Model/library licenses and a public source archive are bundled. No developer backend, advertising or analytics SDK. WebKit renders local sanitized ebook content with network resources blocked; the network-client sandbox entitlement supports its rendering process and is not used for AI requests. User-initiated support/source links open in the system browser. Books, file-access bookmarks, preferences and history stay local; system backups and user exports may contain them. Legacy reading data is retained, but old provider keys are not read or sent. The policy distinguishes the separate GitHub edition.

5. QA and content
The store source passed three local-engine tests, including real inference, follow-up, cancellation, history and legacy-settings compatibility, plus 39 direct-edition regression tests. The universal archive supports Apple silicon and Intel with macOS 13.3+. The signed sandboxed archive passed PDF reading, real local explanation, follow-up, cancellation and bundled TXT sample opening on an Apple M4 Mac mini, macOS 15.7.4. Intel hardware was not tested. Screenshots show actual app views and generated answers. No regulated professional services or third-party book catalog are supplied. The sample is original project content. DeepReader is an independent reader.
