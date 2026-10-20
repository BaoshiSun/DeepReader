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
- Debug always uses Google's sample app/native unit. Release uses this app's IDs. Never click a live ad for testing.

## Behavior

Exactly one slot after the third book, or the last book for libraries with fewer than three. No ad in empty/search/import/reader/history/settings screens. Clearly visible 广告/Ad badge, advertiser icon/name, headline, provider CTA and SDK AdChoices. No clickable card background or navigation disguised as an ad. The production unit serves static images; video rendering is supported defensively if its remote settings change.

The first eligible library visit has a single explanation with agree/decline. Choice is remembered separately from AI settings; disabling ads immediately clears the current ad and drops pending callbacks. Reading/AI are never gated. UMP checks consent before initializing/loading ads. It offers privacy options where required. Requests specify non-personalized ads and restricted data processing; publisher first-party ID is off and the app never requests ATT/IDFA permission or sends book data. No Firebase or mediation SDKs.

One in-flight load, at least 60 seconds between attempts, no periodic refresh while reading, cached ad expiry at 55 minutes. Loading failure is silent and leaves no empty ad card. No fake promotion is substituted for an unfilled ad.

## Build and test

```sh
python3.14 ios/prepare_local_model.py --simulator
python3.14 ios/prepare_project.py
xcodebuild test -project ios/DeepReader.xcodeproj -scheme DeepReaderiOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skip-testing:DeepReaderMobileTests/LocalQwenTests/testStoreListingScreenshots
```

Debug launch argument `--admob-test-preview` skips the local disclosure/UMP flow solely for Google's official sample ad. It is compiled out of Release. Test the actual UMP flow separately with a registered test device and debug geography; never force geography in Release.

20 simulator tests passed: placement/gating, preference persistence/revocation, test-ID separation, ad expiry, PDF/EPUB import/safety, reader layouts, real local Qwen explanation/follow-up/history/cancellation. See local `ios/.build/AdMobTests.xcresult`. These are not physical-device tests.

## Before App Store submission

- Both prior submissions were withdrawn at the owner's request: iOS 1.1.0 (4), macOS 1.3.1 (9), DEVELOPER_REJECTED.
- Build 5 has not been uploaded or submitted. Keep Mac submission separate.
- Publish the European consent message (English + Chinese, direct Do not consent enabled), and configure US choices/restricted data processing. Confirm UMP behavior on a registered test device for EEA, US and other regions.
- After Apple publishes the app, link its App Store listing in AdMob and complete app-readiness/app-ads.txt verification. Until Google approves the app, production filling is not guaranteed.
- App Store shared privacy label MUST change from Data Not Collected before shipping this build. Review the SDK privacy report and actual configuration: coarse location, device/app identifiers, advertising data, product interactions, performance, crashes and other diagnostics. Most ad/interaction identifiers can be linked to a device; do not assume non-personalized means anonymous. Google SDK's generic manifest includes potential tracking, whereas this implementation does not request ATT and disables personalization/PFID. Validate the final label against actual behavior rather than blindly copying the SDK manifest.
- Store descriptions and review-note drafts are updated here; live ASC metadata is not yet changed. Provide current screenshots with the ad label, review advertising-content/age declarations, and physically test iPhone/iPad consent, offline reading, ads/no-fill, search, rotation, large text and privacy revocation. Do not reuse an old video as if it demonstrated build 5.
- `docs/app-store/privacy-policy.md` adds a build-5 section without changing the older Mac/offline editions' data descriptions.

Official references: [native display](https://developers.google.com/admob/ios/native/advanced), [native policies](https://support.google.com/admob/answer/6329638), [UMP](https://developers.google.com/admob/ios/privacy), [data disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure).
