DeepReader iOS 1.0.0 (1) — Guideline 2.1 information

1. Physical-device demonstration
A recording from a physical iPhone running the latest public iOS is required for this resubmission. Recording and device/OS details are pending; they will be attached to the App Review reply before resubmission.

2. Purpose and audience
DeepReader is a free local document reader for individual readers, students and researchers who want to understand their own documents without leaving the reading page. It reads PDF, EPUB, TXT and Markdown, with search, highlights, reading position, ratings and optional AI explanations, follow-ups and summaries in a movable translucent panel. It has no bookstore or enterprise-only access.

3. Setup and main features
No DeepReader registration or login is required; there are no app accounts to delete. No in-app purchases or subscriptions are present. Local reading works without a provider key.
On an empty Library, tap Read a sample (打开示例文章) to open the bundled original bilingual Reading-Garden.txt, or tap Import from Files for your own document. Settings has an English toggle. EPUB displays text-only chapters; Markdown displays source. DRM, MOBI/AZW3, OCR and sync are unsupported.
Touch and hold text to select it. The assistant opens without sending data. Tap Explain; approve the first-use disclosure to send. Drag its title, use minus to collapse or X to close it. Ask a follow-up below a response, or use Summary → Send full text and summarize. Successful responses appear in History. Revoke AI sharing in Settings → Data and privacy. Highlight selected text; PDF highlights can be exported from the reader menu. Long-press a library card to delete its local copy; swipe a History row to delete that record.
For AI, save a valid DeepSeek API key in Settings. Review-only access is provided privately below. Keys use iOS Keychain. DeepSeek fees/quotas apply; the app sells no AI credits.

4. Services and dependencies
DeepSeek (https://api.deepseek.com) is the only external AI service. User-initiated requests go directly there; no developer backend or relay exists. Explanations send selection/context, follow-ups add prior answers/questions, and summaries send extracted full text in sections. No document binary is uploaded. Local reading uses Apple PDFKit, SwiftUI/UIKit, Files and Keychain; ZIPFoundation 0.9.20 locally extracts EPUB archives. GitHub hosts public source, support and privacy documents. No external authentication, payments, advertising, tracking or analytics SDK is included.

5. Regions
The same binary and features are supplied in all selected regions; there is no region-specific catalog or developer-controlled feature restriction. Chinese/English UI is user-selectable. DeepSeek availability, provider terms, account quotas and network access can differ independently by region. Offline reading remains available without AI.

6. Content and rights
The app does not provide medical, financial or other regulated professional services. It has no public posts, user profiles, messaging or hosted user-content feed. Imported documents and AI history are private local data; the app does not distribute users' documents to other users. The bundled Reading Garden sample is original project content. Original Swift code is AGPL-3.0-or-later; ZIPFoundation is MIT; the existing icon is attributed to Alex under CC BY 3.0 with modification notices. Licenses/attribution are in Settings → Open-source licenses and the public source. iOS does not link SumatraPDF, MuPDF or libmobi. DeepReader is independent of DeepSeek and SumatraPDF.

Review-only provider access follows in the private App Store Connect field.
