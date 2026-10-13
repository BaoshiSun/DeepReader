DeepReader iOS 1.1.0 (2) — Guideline 2.1 information

1. Physical-device demonstration
Existing video of version 1.0.0: DeepReader-iPhone14Pro-demo.mp4 (attached to the review reply). Recorded on a physical iPhone 14 Pro; the developer reports iOS 26.6.2. It shows launch, settings, local reading, text selection, a successful AI explanation and History. Only the first 3 seconds of unrelated personal content were trimmed; the remaining flow is continuous. Books shown are user-imported, not supplied by the app.

2. Purpose and audience
DeepReader is a free local document reader for individual readers, students and researchers who want to understand their own documents without leaving the reading page. It reads PDF, EPUB, TXT and Markdown, with search, highlights, reading position, ratings and optional AI explanations, follow-ups and summaries in a movable translucent panel. It has no bookstore or enterprise-only access.

3. Setup and main features
No DeepReader registration or login is required; there are no app accounts to delete. No in-app purchases or subscriptions are present. Local reading works without a provider key.
On an empty Library, tap Read a sample (打开示例文章) to open the bundled original bilingual Reading-Garden.txt, or tap Import from Files for your own document. Settings has an English toggle. EPUB displays text-only chapters; Markdown displays source. DRM, MOBI/AZW3, OCR and sync are unsupported.
Touch and hold text to select it. The assistant opens without sending data. Tap Explain; approve the first-use disclosure to send. Drag its title, use minus to collapse or X to close it. Ask a follow-up below a response, or use Summary → Send full text and summarize. Successful responses appear in History. Revoke AI sharing in Settings → Data and privacy. Highlight selected text; PDF highlights can be exported from the reader menu. Long-press a library card to delete its local copy; swipe a History row to delete that record.
Wide windows offer a right AI sidebar with a draggable divider and a floating-mode toggle; narrow windows use the floating panel. Choose Book only or General knowledge (no browsing) for the answer scope. The latter adds learned background knowledge, without web search. Sharing permission and keys are bound to the selected provider and endpoint; changing the recipient requires new permission.
For AI, save a valid provider API key in Settings. DeepSeek remains the default review path. Review-only access is provided privately below. Keys use iOS Keychain. DeepSeek fees/quotas apply; the app sells no AI credits.

4. Services and dependencies
Version 1.1.0 offers DeepSeek, OpenAI, Claude, Gemini, Qwen, Kimi, GLM, Doubao, MiniMax, Grok, Mistral, OpenRouter and custom compatible endpoints for text chat models. User-initiated requests go directly to the selected provider/endpoint; OpenRouter forwards to downstream model providers. No developer backend or relay exists. Explanations send selection/context, follow-ups add prior answers/questions, and summaries send extracted full text in sections. No document binary is uploaded. Local reading uses Apple PDFKit, SwiftUI/UIKit, Files and Keychain; ZIPFoundation 0.9.20 locally extracts EPUB archives. GitHub hosts public source, support and privacy documents. No external authentication, payments, advertising, tracking or analytics SDK is included.

5. Regions
The same binary and features are supplied in all selected regions; there is no region-specific catalog or developer-controlled feature restriction. Chinese/English UI is user-selectable. Provider availability, terms, account quotas and network access can differ independently by region. Offline reading remains available without AI.

6. Content and rights
The app does not provide medical, financial or other regulated professional services. It has no public posts, user profiles, messaging or hosted user-content feed. Imported documents and AI history are private local data; the app does not distribute users' documents to other users. The bundled Reading Garden sample is original project content. Original Swift code is AGPL-3.0-or-later; ZIPFoundation is MIT; the existing icon is attributed to Alex under CC BY 3.0 with modification notices. Licenses/attribution are in Settings → Open-source licenses and the public source. iOS does not link SumatraPDF, MuPDF or libmobi. DeepReader is independent of DeepSeek and SumatraPDF.

Review-only provider access follows in the private App Store Connect field.
