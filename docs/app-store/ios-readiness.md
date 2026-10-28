> Current status — 2026-10-23: iOS 1.1.0 (5) is **Waiting for Review**, submitted at 01:53 Asia/Riyadh. macOS 1.3.1 (9) was separately resubmitted without ads at 02:01 and is also Waiting for Review. Historical records below are superseded by this entry.

## iOS library advertising release — 2026-10-23

App Store Connect confirmed **Waiting for Review** for iOS **1.1.0 (5)**. Submission ID: `c376efed-e84c-40e0-ad6b-143a3d957918`. [Open submission](https://appstoreconnect.apple.com/apps/6821368213/distribution/reviewsubmissions/details/c376efed-e84c-40e0-ad6b-143a3d957918). This is a submission, not an approval or publication.

- Owner authorized upload and App Review submission after confirming the library ad is visible on iPhone and reading remains ad-free.
- Archive, App Store export and Xcode upload succeeded at 01:47 Asia/Riyadh. Apple processing completed (VALID), and the iOS version selects build 5. Build identifier: `0e023673-340e-4b05-8636-3768136d2703`.
- Physical iPhone 14 Pro / iOS 26.6.2: 7 tests passed using the separate Local debug identity, including real Qwen explanations/follow-ups/history/cancellation, legacy settings and advertising policy. Earlier simulator suite: 20 passed. Google native-ad validator passed on iPhone and iPad simulators. No physical iPad testing is claimed.
- Release uses the production AdMob app/unit IDs. Sample-ad bypass and forced EEA geography are absent from Release. No ATT usage prompt is included. `gad_rdp=true` is set before Google Mobile Ads initialization; NPA/RDP request extras and disabled PFID remain in place.
- Chinese/English store descriptions and support links, review notes, shared privacy-policy links, advertising age-rating flag and all seven App Privacy data types were saved. Age override remains 16+. Public support/privacy documents are hosted on `codex/ios-library-admob`.
- Free prices and all 175 available storefronts were verified in App Store Connect. Automatic release after approval remains selected. No IAP is submitted.
- Existing reading screenshots are retained. The physical-device October 15 recording is retained and explicitly identified as earlier footage of the unchanged offline workflow without ads.
- Archive and proofs: `artifacts/ios-admob-store/`; physical tests: `DeviceQA.xcresult`; privacy proof: `privacy-published.png`; submission proof: `waiting-for-review.png` and `submission-result.json`. Generated files are ignored by Git. Google Mobile Ads/UMP vendor dSYMs were not included in the distributed frameworks and produced non-blocking upload warnings; app and matching llama symbols were included.
- AdMob app-readiness/store-linking remains separate from Apple review. Production ads may not fill until Google approves the public app. See [advertising details](ios-advertising.md).

# iOS App Store submission — 2026-10-11

Owner authorized submission of iOS to the existing app record (6821368213), free in CHN/HKG/MAC/TWN/SAU/ARE/QAT/KWT/BHR/OMN. Release uses org.deepreader.macos; Debug retains org.deepreader.ios. No migration of local test-install data is claimed. macOS 1.2.1 (5) is already Waiting for Review.

The owner reported physical-device testing without remaining issues. Automated suite: 15 iOS tests passed, including real isolated Keychain tests and offline transport consent tests. Floating layout regression passed after final appearance changes. No private review key was used locally; no live provider request was made by the agent.

## Submission result

App Store Connect confirmed **Waiting for Review** for iOS **1.0.0 (1)** on 2026-10-11 at 00:58 Asia/Riyadh. Submission ID: `ec13236a-878d-4e69-aa1f-0913d2fba681`; build ID: `c0d0bc3f-38cb-4d1c-93ff-23aa27b0c522`. Automatic release after approval is selected. macOS 1.2.1 remains Waiting for Review.

- Signed archive and App Store export/upload succeeded with Xcode 26.3 / iPhoneOS 26.2 SDK. Release icon is opaque.
- Chinese and English iOS descriptions, support URLs and private reviewer instructions are saved. Existing review credentials remain only in App Store Connect.
- Actual Release-app simulator screenshots: two iPhone images per language at 1320×2868 and one iPad image per language at 2064×2752. Apple accepted them; required smaller iPhone assets inherit the large-display images.
- Combined Mac/iOS privacy URL is saved for both localizations. Shared Books/Education categories, age rating 16+ (regional/older-OS variations), free pricing and ten authorized territories were verified.
- Local archive: `artifacts/ios-app-store/DeepReader-1.0.0-1.xcarchive`; upload log: `artifacts/ios-store-upload.log`; screenshots and submission proof: `artifacts/ios-app-store/`. These generated files are intentionally not tracked.
- On the freshly booted iPad simulator, the first sample import left the progress UI visible although the document was saved. After relaunch the book opened normally. This observation was not reproduced on the tested iPhone; it does not establish a cause or replace physical-iPad testing.
- GitHub served its temporary outage page (HTTP 503) while checking the public policy/support links; the branch push and remote commit were verified. Recheck public document availability if the outage persists.

[App Store Connect submission](https://appstoreconnect.apple.com/apps/6821368213/distribution/reviewsubmissions/details/ec13236a-878d-4e69-aa1f-0913d2fba681)


Licenses unchanged: original Swift code AGPL-3.0-or-later, ZIPFoundation MIT, existing icon CC BY 3.0 attribution. iOS does not link libmobi, SumatraPDF or MuPDF. This is not a legal compatibility determination.

## Guideline 2.1 follow-up — 2026-10-11

The first submission was rejected with “Information Needed - New App Submission” because the account has limited review history. The message requests six items: a physical-device recording on the latest OS, purpose/audience, setup and feature access, external services, regional differences, and relevant regulated-service/content documentation. It does not identify a specific crash or functional defect.

The iOS App Review Notes were expanded with the six numbered sections; sections 2–6 are complete, while section 1 explicitly remains pending a genuine device recording and device/OS details. Existing private review credentials remain only in App Store Connect. No binary change or new build was made for this information request. No review reply or resubmission has been sent yet.

The known iPhone 14 Pro was unavailable to the development host during preparation. The owner was asked for an existing recording and iOS version. Use [the recording checklist](ios-review-recording.md); do not substitute simulator footage or claim physical-device testing not performed.

## Physical-device recording received — 2026-10-11

The owner supplied a 77.93-second iPhone screen recording and identified the device as iPhone 14 Pro running iOS 26.6.2 (owner-reported; the OS version is not independently established by the recording). The visible About screen shows DeepReader iOS 1.0.0. The video shows launch, settings, local reading, selected-text AI explanation with a successful response, and History. The recorded documents were imported by the user; they are not the bundled sample or an app-provided catalog.

A private review copy, `artifacts/ios-app-store/review-video/DeepReader-iPhone14Pro-demo.mp4`, omits the first 3 seconds because unrelated personal photos appeared in the app switcher. The remainder is continuous, about 74.93 seconds, with the launch preserved. The original is unchanged. Neither the recording nor extracted frames are tracked or uploaded to the public repository.

After owner sign-in, App Review Notes were updated with the recording details while preserving private review access. Once the owner enabled the Chrome extension file-upload permission, the video uploaded successfully and was sent with the six-section review reply. App Store Connect displayed the attachment under the sent message.

## Resubmission result — 2026-10-11

At 13:11 Asia/Riyadh, App Store Connect confirmed **Waiting for Review** for iOS **1.0.0 (1)** after updating the review item and resubmitting. The submission ID remains `ec13236a-878d-4e69-aa1f-0913d2fba681`, and the selected build remains `c0d0bc3f-38cb-4d1c-93ff-23aa27b0c522`. No binary change was needed for this information request.

The six requested information sections are present in both the sent reply and App Review Notes. The private review key is retained only in App Store Connect. The video is an attachment to the reply, not a public repository asset. Local proof: `artifacts/ios-app-store/resubmitted-review.jpg`. The macOS submission was not modified.

## Unreleased multi-provider changes — 2026-10-12

New development source supports 12 named providers plus a custom compatible endpoint. No submitted binary or App Store metadata was changed by this development work. Before a new submission: complete real-account checks for intended providers and regions; review Gemini/OpenRouter 18+ terms and overall audience; update store descriptions, reviewer instructions, screenshots, age rating and privacy labels for actual recipients/downstream routing. The app’s age confirmation is only one control, not a legal compliance determination. Windows CI compiled the native AI panel and passed 121 core checks; the legacy helper compiled and passed 67 offline checks. Complete Windows packaging and manual GUI verification remain. See the root README and privacy-policy supplement.


## 2026-10-14: rejection and local provider-restriction candidate

Apple rejected iOS 1.1.0 (2), submission `cbb9ec8c-6d42-495b-a460-69d73edb2921`, under Guideline 5 (China mainland / OpenAI functionality and metadata) and 3.1.1 (paid functionality enabled through third-party API keys). The user chose to retain the other AI providers and request clarification about 3.1.1, rather than remove all AI or implement billing now.

Local store-edition changes remove OpenAI and Claude choices, OpenRouter/custom gateways and arbitrary endpoint overrides. Both Apple platforms share the restriction and validate it before creating requests. Saved unsupported provider selections fall back to DeepSeek; credentials and reading history are not deleted. Direct-distribution macOS builds retain the full provider list. Remaining direct endpoints and model availability must still be checked against provider regional requirements; these changes do not establish China compliance or resolve 3.1.1.

The store listing JSON files are replacement-build drafts. No replacement binary, screenshots or live store descriptions have been uploaded in this change. The existing 99-second video demonstrates build 2 and must not be described as a recording of the modified candidate. Before resubmission, assign a new build number, update screenshots/Review Notes/privacy documentation to that exact candidate, and physically test it. Do not resubmit unchanged build 2 as though the provider restrictions were present.

Validation: 35 macOS tests and 22 iOS tests passed, including the store policy, legacy settings, endpoint restrictions and retained direct-provider requests. iOS ran offline on an iPad Air 11-inch (M3) simulator with iOS 26.3, not a physical iPad. No live API calls or new keys were used. The 3.1.1 / China-service clarification was sent in the existing iOS review conversation on 2026-10-14 at 22:21 Asia/Riyadh; the page shows two messages. Screenshot and exact sent text are retained locally under `artifacts/ios-app-store/provider-restrictions/`.

## 2026-10-15: offline Qwen replacement 1.1.0 (3)

The App Store archive was signed and uploaded successfully. Build ID:
`7f43e652-86b1-4e19-994c-acbc64e6c2a5`. The version selects build 3 rather
than rejected build 2. All AI runs through bundled Qwen3 0.6B / llama.cpp,
with no API key, remote AI fallback or purchase flow. Accuracy warnings
appear in the assistant, Settings and both store localizations.

The corresponding source and support/privacy documents are published on
`codex/ios-offline-qwen-store`. Chinese and English store descriptions and
iPhone/iPad screenshots were replaced. The shared privacy policy explains
the offline iOS edition separately from macOS.

An explanatory reply was sent in submission
`cbb9ec8c-6d42-495b-a460-69d73edb2921` at 09:39 Asia/Riyadh. It describes
the changes addressing 3.1.1 and 5 and does not claim guaranteed approval.
The old build-2 video is explicitly identified as superseded. Physical
device QA refers to the separately signed local variant on iPhone 14 Pro,
iOS 26.6.2; the store variant passed simulator inference/layout tests.

App Store Connect confirmed **Waiting for Review** for **1.1.0 (3)** on
2026-10-15 at **09:42 Asia/Riyadh**. The resubmission contains one item, the
iOS app version. No IAP was attached. Automatic release after approval
remains selected. The separate macOS 1.3.1 submission was not replaced.
Local submission proof: `artifacts/ios-offline-store/review-submitted.jpg`.

### Offline physical-device recording added

On 2026-10-15, the current App Review attachment was replaced with
`DeepReader-Local-Qwen-iPhone14Pro-2026-10-15.mp4` (115.14 seconds).
The file is an unchanged copy of the user-provided recording, with a lowercase
`.mp4` extension for App Store Connect compatibility. SHA-256:
`fd757fcfe2315c61bd1cc54f57f8c4754852ddfe0f26ed7a2648a8b9767c20fc`.

The recording demonstrates launching the local variant on iPhone 14 Pro,
reading, Qwen explanations, history, language/settings and floating layout.
Review Notes explicitly distinguish this development variant from the exact
App Store build-3 binary and explain that displayed documents are tester
imports, not bundled content. The video is only an Apple review attachment;
it is not published with the source repository.

## Free offline iOS consolidation — 2026-10-19

The owner chose free iOS distribution without ads or paid question credits. All iOS configurations now
bundle Qwen, including the default checked-in project. Candidate 1.1.0 (4) removes the online client,
Keychain credential and purchase implementations from iOS compilation, removes the advertising build
option and UI, and preserves library/history compatibility, answer scope and floating/sidebar layouts.
The library uses single-column book rows. Accuracy warnings remain visible.

The previously uploaded 1.1.0 (3) already provided free offline Qwen. The newer source must not be
represented as live until upload and App Store Connect verification are complete. At the start of this
work, App Store Connect required the owner to sign in again. No price or storefront changes have been
verified in this session yet. Previously authorized storefronts remain mainland China, Hong Kong,
Macau, Taiwan and the six Gulf countries; this is not a worldwide availability change.

Analytics plan: use Apple's aggregate download, engagement and crash metrics with iOS filters, without
adding a tracking SDK. Opt-in and privacy thresholds limit usage statistics; no per-question or book-content
telemetry is collected. Historical review recordings remain labeled with their original build/variant.

Validation on 2026-10-19: 16 iOS simulator tests passed (iPhone 17 / iOS 26.3), including actual
Qwen inference and iPhone/iPad layout renders; 2 physical iPhone 14 Pro / iOS 26.6.2 tests passed
in the build-4 local development identity, covering actual answers/follow-up/cancellation/history and
legacy provider settings. The two short device answers took 1.14 s and 0.83 s, not a general latency
benchmark. All 39 macOS regression tests passed. Store archive signing and strict signature verification
passed. Model SHA-256 matched the pinned artifact, and the archive has no remote AI, credential or
purchase symbols and no ad/tracking frameworks. Matching llama dSYM UUID was included before upload.

After owner sign-in, App Store Connect showed iOS 1.1.0 (3) still Waiting for Review, automatic
release after approval, and 175 available storefronts with zero prices. The owner explicitly confirmed
keeping all 175 storefronts on 2026-10-19, superseding the earlier ten-storefront preference.

Build 4 upload succeeded on 2026-10-19 at 23:20 Asia/Riyadh via Xcode App Store Connect
export/upload with symbols enabled. Upload success is not approval or submission.

## 2026-10-20: build 4 submitted for review

At 13:11 Asia/Riyadh, the official App Store Connect API confirmed **Waiting for Review**
for iOS **1.1.0 (4)**. Submission ID: `676e2b1b-2282-4787-9f54-cec74434531c`;
build ID: `3bca0aff-a384-4d0d-a3a9-95e9c07befe2`.
The earlier build-3 submission was canceled and its review item removed before replacement.

Both English and Simplified Chinese descriptions now explicitly state free reading and offline AI,
no advertising, subscriptions or question quota. Review Notes were updated for build 4 while preserving
the existing physical-device video, accurately labeled as the earlier local development variant.
No login is required. No purchase product was added to this submission.

Automatic release after approval remains selected. The previously verified free prices and
owner-confirmed 175 storefronts were retained. No approval or public availability is claimed.
Publishing authentication is configured locally outside the repository; no private key or access
token is included in the source, app, or public documentation.
