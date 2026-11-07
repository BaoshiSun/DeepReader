DeepReader iOS/iPadOS 1.1.1 (6) is a free document reader with bundled, on-device Qwen3 0.6B AI. No login, API key, purchases, subscription or question quota is required.

1. Purpose of this update
This update adds our developer website, https://baoshisun.github.io/, to both App Store localizations. Its root app-ads.txt authorizes our existing Google AdMob publisher. Version/build numbers were incremented; the compiled app source, model, SDK versions, reading features, privacy choices and ad unit IDs are unchanged from approved iOS 1.1.0 (5). No new advertising feature or third-party AI service is added.

2. AI runs entirely on device
The Qwen model is included in the installation. llama.cpp generates explanations and follow-ups locally. Books, titles, selections, context, questions, answers and history are not sent to Alibaba/Qwen, any AI provider, or the developer. There is no remote AI API, cloud fallback, web search, or runtime model download. General knowledge uses the model's learned knowledge. AI answers may be inaccurate or incomplete; warnings appear in the assistant, Settings and store descriptions.

3. Review setup and main workflow
Disable both Wi-Fi and cellular data. Launch DeepReader. In an empty Library, tap Read a sample / 打开示例文章, or import a local PDF, EPUB, TXT or Markdown file. Select a short passage, tap Explain, wait for generation, and ask a follow-up. No credentials or sample download is required. Settings shows On-device AI / Qwen3 0.6B. Both answer-scope options work offline. The bundled Reading Garden article is original. This app is for individuals reading their own documents; there are no accounts, public posting, paid features or regulated services.

4. Optional ads are separate from AI
Google advertising starts only after the local disclosure and user opt-in; UMP handles applicable regional choices. One labelled native image ad may appear in Library, never in the reader, search, History or an empty library. Declining/disabling ads or going offline preserves all reading and AI features. Reading content is not passed to the ad service. Requests use non-personalized ads and restricted processing, disable publisher first-party ID, and do not request ATT. Google SDK data processing is described in App Privacy and our policy. No Firebase Analytics or developer backend is used.

5. Validation and previously supplied physical-device video
On 2026-11-08, all 20 existing simulator regression tests passed on iPhone 17 Pro / iOS 26.3, including actual bundled AI explanation/follow-up/cancellation/history, document handling, layout and ad-consent policy. Signed archive, production ad IDs and bundled model checksum were verified.
The same functional source previously passed 7 tests on iPhone 14 Pro / iOS 26.6.2 on 2026-10-23. No new physical-device test is claimed for build 6.
The attached ScreenRecording_10-28-2026 2.MP4 is the previously supplied 2m29s physical-device demonstration: airplane mode and Wi-Fi off, launch, Settings, and new local answers in both scopes. It shows the earlier separately signed Local development variant, not the new App Store binary; the demonstrated AI workflow is unchanged.

6. Components and availability
Qwen3 0.6B, llama.cpp, ZIPFoundation, Google Mobile Ads 13.11.0, UMP 3.1.0 and Apple frameworks. Licenses remain in Settings. The same free local AI is available across all selected storefronts; ad availability and consent may vary. The retired question-credit IAP remains unused and is not submitted.
