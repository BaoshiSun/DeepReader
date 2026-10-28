# iOS 1.1.0 (5) — App Review Notes

DeepReader iOS/iPadOS 1.1.0 (5) is a free document reader with bundled, on-device Qwen3 0.6B AI. No login, API key, purchases, subscription or question quota is required.

1. Response to Guidelines 5.1.1(i) / 5.1.2(i)
This build does NOT send personal data to a third-party AI service. Qwen is a model file included in the app, not a cloud service. llama.cpp generates explanations and follow-up answers locally. Documents, titles, selections, nearby context, questions, answers and reading history are not sent to Alibaba/Qwen, another AI provider or the developer. No remote AI API, cloud fallback, web search or runtime model download is used. General knowledge uses the local model's learned knowledge, not Internet search.
We clarified the public privacy policy on 2026-10-28 and moved earlier online-edition descriptions to a separate archive. Those earlier descriptions do not apply to this build. The policy distinguishes local AI from optional Google advertising. The existing build 5 already implements this local processing; this resubmission clarifies documentation, with no binary change.

2. Reproduce local AI on iPhone or iPad
Disable both Wi-Fi and cellular data (Airplane Mode alone can leave Wi-Fi enabled). Launch the installed app. In an empty Library, tap Read a sample / 打开示例文章; otherwise open a local document. Select a short sentence, tap Explain, wait for generation, and ask a follow-up. No credentials are needed. Settings shows On-device AI / Qwen3 0.6B; Book only and General knowledge both work offline. AI answers may be inaccurate or incomplete; warnings appear in the assistant, Settings and store descriptions.

3. Setup and audience
For individuals reading their own documents. Import PDF, EPUB, TXT or Markdown using Files. Wide screens have an adjustable sidebar or floating panel; narrow screens use a floating panel. Settings switches English/Chinese. Successful answers remain in local History. No full-document summary, OCR, DRM, accounts, public posting or regulated service. Reading Garden is original sample content; tester-imported books are not bundled content.

4. Optional advertising is separate from AI
The first library ad prompt explains Google's data use with Agree / Continue without ads. No ads/consent SDK starts before opt-in. Settings can disable ads without losing reading or AI. Google UMP provides applicable regional privacy choices. One labelled native image ad may appear in Library, never in the reader, search, History or an empty library. No rewarded unlock exists. The app does not provide reading content or conversations to Google. We request non-personalized ads and restricted processing, disable publisher first-party ID, and do not request ATT. Advertising can involve IP-derived location, identifiers, interactions and diagnostics as disclosed in App Privacy and the policy. No-fill/offline use never blocks reading or AI. No developer backend or Firebase Analytics.

5. QA and video
Seven tests passed on a physical iPhone 14 Pro / iOS 26.6.2 on 2026-10-23 using the separately signed build-5 Local development variant with the same source/engine; 20 simulator tests passed. No physical iPad test is claimed.
New App Review Information attachment: ScreenRecording_10-28-2026 2.MP4 (2m29s). At 00:02-00:08 the owner enables Airplane Mode and turns Wi-Fi off, then launches DeepReader Local. At 00:10-00:20 it shows On-device AI Settings; 00:44-01:05 shows a new explanation in General knowledge mode; 02:00-02:16 shows generation and an answer in Book only mode, with the airplane icon and no Wi-Fi connection icon. This is the separately signed Local development variant, not the App Store binary.

6. Components and availability
Qwen3 0.6B (Apache 2.0), llama.cpp (MIT), ZIPFoundation (MIT), Google Mobile Ads 13.11.0, UMP 3.1.0, Apple frameworks. Licenses are in Settings. Same free local AI in all 175 selected storefronts; ad availability and consent may vary. Earlier question-credit IAP is unused and not submitted.

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
