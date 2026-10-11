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
