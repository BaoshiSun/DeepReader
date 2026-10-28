# iOS library advertising — build 5

The owner requested one book-like native ad row in the library. Reading and Qwen remain free/offline. macOS and Windows have no changes in this work.

## Configuration

- AdMob account: shengxi (account approval confirmed in its dashboard).
- iOS app: DeepReader: Read with AI, not yet linked to a public store listing.
- App ID: `ca-app-pub-9226197175186931~9369232249`.
- Native unit: Library Native Row, `ca-app-pub-9226197175186931/1421178207`.
- Media: Image on, Video off. Google-optimized floor / all prices.
- These are public identifiers, not secrets. `ios/Advertising.json` drives project generation.
- GoogleMobileAds 13.11.0 and GoogleUserMessagingPlatform 3.1.0 are pinned with SPM.
- Debug uses the real app ID to test its UMP messages, with Google's sample native unit. Release uses the production native unit. Never click a live ad for testing.

## Behavior

Exactly one slot after the third book, or the last book for libraries with fewer than three. No ad in empty/search/import/reader/history/settings screens. Clearly visible 广告/Ad badge, advertiser icon/name, headline, provider CTA and SDK AdChoices. No clickable card background or navigation disguised as an ad. The production unit serves static images; video rendering is supported defensively if its remote settings change.

The first eligible library visit has a single explanation with agree/decline. Choice is remembered separately from AI settings; disabling ads immediately clears the current ad and drops pending callbacks. Reading/AI are never gated. UMP checks consent before initializing/loading ads. It offers privacy options where required. Requests specify non-personalized ads and restricted data processing (`rdp=1`); `gad_rdp=true` is set in UserDefaults before initializing Google Mobile Ads, following Google's current iOS guidance; publisher first-party ID is off and the app never requests ATT/IDFA permission or sends book data. No Firebase or mediation SDKs.

One in-flight load, at least 60 seconds between attempts, no periodic refresh while reading, cached ad expiry at 55 minutes. Loading failure is silent and leaves no empty ad card. No fake promotion is substituted for an unfilled ad.

## Build and test

```sh
python3.14 ios/prepare_local_model.py --simulator
python3.14 ios/prepare_project.py
xcodebuild test -project ios/DeepReader.xcodeproj -scheme DeepReaderiOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skip-testing:DeepReaderMobileTests/LocalQwenTests/testStoreListingScreenshots
```

Debug launch argument `--admob-test-preview` skips the local disclosure/UMP flow solely for Google's official sample ad. `--admob-consent-eea` instead exercises the real UMP message using EEA debug geography; simulators are UMP test devices. Both flags are compiled out of Release. Register physical test devices before using debug geography; never force geography in Release.

20 simulator tests passed: placement/gating, preference persistence/revocation, test-ID separation, ad expiry, PDF/EPUB import/safety, reader layouts, real local Qwen explanation/follow-up/history/cancellation. See local `ios/.build/AdMobTests.xcresult`. These are not physical-device tests.

Manual verification completed on 2026-10-23:

- iPhone 17 Pro and iPad Air 11-inch (M3), iOS 26.3: official sample native ads loaded. Google's native-ad validator reported **No implementation issues found** on both.
- Real European UMP message displayed on the iPhone simulator. **Do not consent** returned to the app; **Manage Google privacy choices** reopened the form. Disabling **Allow library ads** persisted and reading the bundled sample remained available.
- Release iPhoneOS build succeeded after the layout fix. Its compiled Info.plist contains the production IDs; the binary contains neither debug bypass nor forced-geography launch flags. No ATT usage description is present.
- Five advertising tests passed again after the layout/test-ID changes. Screenshots are saved locally under `artifacts/admob/` (ignored by Git).

The European message **DeepReader library privacy** is published in AdMob, with a direct **Do not consent** option and Google Advertising Products as its one configured ad partner. Its privacy-policy link points to this branch's updated policy. English rendering is verified; additional message language coverage still needs review before global release.

## App Store submission — 2026-10-23

- User confirmed the build-5 sample ad appears in the physical iPhone library and no ad appears in the reader.
- Seven tests passed on iPhone 14 Pro / iOS 26.6.2 using the separate Local development variant: real Qwen explanation/follow-up/history/cancellation, legacy settings and five advertising-policy tests. Result: `artifacts/ios-admob-store/DeviceQA.xcresult`. No physical iPad test is claimed.
- Release archive/export/upload succeeded. Matching llama dSYM was included. Xcode reported non-blocking missing dSYM warnings for Google's prebuilt Mobile Ads and UMP frameworks; upload succeeded, but crash symbolication inside those vendor binaries may be limited.
- Both store descriptions, support/policy links, review notes and advertising age-rating flag were updated. Shared App Privacy was published with seven data types. Coarse location, device ID, advertising data, product interactions and performance data are disclosed as linked; crash/other diagnostics as unlinked. None are declared for tracking under this NPA/RDP/no-ATT/PFID-disabled configuration. Advertising/analytics purposes are disclosed, with App Functionality for UMP-related coarse location, performance and interactions. The performance linkage is conservative relative to the bundled manifest and Google's public data-disclosure guidance.
- The dated physical-device recording from October 15 is retained as a demonstration of the unchanged offline workflow and is explicitly identified as an earlier build without ads. It is not described as build-5 footage.
- Google documents direct RDP signalling as an alternative to GPP signalling. This build uses direct RDP and provides its own optional-ad switch; a separate US UMP message is not configured. Forced EEA simulator testing does not establish testing in all regions.
- Existing reading screenshots still show the unchanged offline assistant. Google sample advertisements are not presented as production inventory in store screenshots.
- iOS 1.1.0 (5) is Waiting for Review, submitted at 01:53 Asia/Riyadh. See [readiness](ios-readiness.md) for the build/submission IDs. macOS 1.3.1 (9) was separately resubmitted without ads at 02:01 and is also Waiting for Review; see [Mac readiness](readiness.md).

## After publication

Link the public App Store listing in AdMob and complete Google's app-readiness/app-ads.txt requirements. Production filling is not guaranteed before approval. Review the additional UMP translations and real regional consent behavior as coverage expands; only English EEA rendering is currently verified.

Official references: [native display](https://developers.google.com/admob/ios/native/advanced), [native policies](https://support.google.com/admob/answer/6329638), [UMP](https://developers.google.com/admob/ios/privacy), [data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure), [US states and RDP](https://developers.google.com/admob/ios/privacy/us-states), [Apple privacy details](https://developer.apple.com/app-store/app-privacy-details/).
