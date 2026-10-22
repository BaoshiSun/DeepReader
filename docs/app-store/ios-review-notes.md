# iOS 1.1.0 (5) — App Review Notes

DeepReader iOS 1.1.0 (5) is a free iPhone/iPad document reader with bundled, on-device Qwen3 0.6B AI. No login, API key, remote AI, purchases, subscriptions or question quota. AI answers may be inaccurate; warnings appear in the assistant, Settings and store descriptions.

1. Changes and previous Guidelines 3.1.1 / 5
All AI runs locally through llama.cpp. No paid unlock, external payment, provider selection, cloud fallback, web search or model download is available. The earlier question-credit IAP is not used or submitted. The app now offers one optional, clearly labelled AdMob native image ad in the library. There are no ads in the reader, search results, History or an empty library. No viewing/clicking requirement or rewarded unlock exists.

2. Purpose and setup
For individuals, students and researchers reading their own documents. In the empty Library, tap Read a sample / 打开示例文章, or import PDF, EPUB, TXT or Markdown from Files. Select a short passage, tap Explain and ask a follow-up. Wide screens offer an adjustable sidebar or floating panel; narrow screens use a draggable/collapsible floating panel. Settings switches English/Chinese and Book only / General knowledge. Both modes work offline. Successful answers remain in local History. Full-document summaries, OCR and DRM are not supported.

3. Advertising and privacy
Return to Library after opening the sample. The first eligible library visit offers Agree or Continue without ads. Allow library ads in Settings can disable ads without losing any feature. Google UMP provides applicable privacy choices, including Do not consent and a Settings link to revisit choices. Ads are non-personalized, restricted data processing is enabled, publisher first-party ID is disabled, and no ATT permission is requested. Book titles/text, selections, questions and answers are not sent to advertising services. One ad appears after the third book, or the last book when fewer than three exist. Production ad availability depends on Google's separate readiness checks; no-fill is handled without an empty card. Offline reading and AI remain available.

4. Components and regions
Google Mobile Ads 13.11.0, UMP 3.1.0, Qwen3 0.6B Q4_K_M (Apache 2.0), llama.cpp (MIT), ZIPFoundation (MIT), Apple frameworks. No developer backend or Firebase Analytics. Updated App Privacy and policy disclose Google's advertising/consent data. The same free offline features are offered in all 175 selected storefronts; advertising availability and consent forms may vary by region.

5. Testing and video
On 2026-10-23, seven tests passed on a physical iPhone 14 Pro with iOS 26.6.2 using the separately signed build-5 Local development variant with the same source/engine. They cover real Qwen explanation/follow-up/history/cancellation, legacy settings and advertising policy. The owner confirmed a library ad appeared and no ad appeared in the reader. Debug uses Google's official sample ad; Release uses the production unit. Twenty simulator tests passed, and native-ad validation passed on iPhone and iPad simulators. No physical iPad test is claimed.
The existing attachment DeepReader-Local-Qwen-iPhone14Pro-2026-10-15.mp4 shows launch, reading, local AI, history, settings/language and floating assistant on iPhone 14 Pro / iOS 26.6.2. It is an earlier local development build, not build 5, and does not show the new ads. The core offline workflow remains the same. Documents imported by the tester are not bundled content.

6. Content and rights
No accounts, public posting, messaging, protected catalog or regulated service. Users import their own documents. Reading Garden is original sample content. Open-source/model licenses and icon attribution are included in Settings. This is an independent reader.

---

## Previous build-4 review notes (historical)

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
