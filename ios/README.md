> Current advertising branch: iOS build 5 adds one labelled AdMob native image row to the library. Reading and bundled Qwen stay free and offline. Use [the integration and release checklist](../docs/app-store/ios-advertising.md); earlier no-ads statements below refer to builds 3–4.

# DeepReader for iPhone and iPad

All iOS build configurations now include **Qwen3 0.6B Q4_K_M** and run AI on device.
The app is free, with no advertisements, subscriptions, purchases, API keys or question quota.
No remote AI client, Keychain credential implementation, StoreKit gateway, advertising SDK
or analytics SDK is compiled into the iOS application. The model is bundled, with no first-launch download.

Current App Store submission: **1.1.0 (4)**, **Waiting for Review** as of
2026-10-20 at 13:11 Asia/Riyadh. It replaces build 3, with free pricing in the
175 selected storefronts and automatic release after approval. Submission is not approval
or publication; see the dated record in [readiness](../docs/app-store/ios-readiness.md).

## Build and run

Requires Xcode, iOS/iPadOS 17 or later, and approximately 500 MB for the installed app.
Prepare the pinned model/framework once:

```sh
python3 ios/prepare_local_model.py --simulator
python3 ios/prepare_project.py
open ios/DeepReader.xcodeproj
```

The default project is now offline too. Debug uses `org.deepreader.ios`;
Release uses `org.deepreader.macos`, joining the existing App Store record 6821368213.
`--store-qwen` generates the compatible `DeepReaderOfflineStore.xcodeproj` alias with the
store identity in both configurations. `--local-qwen` produces a separate
`DeepReaderLocal.xcodeproj` / `org.deepreader.ios.local` development app. All three include
the same offline engine and free features. These distinct development identities have separate libraries.
The retired `--ads-test` option is rejected.

For devices only, omit `--simulator` when preparing resources. See
[model provenance, licenses and runtime limits](LOCAL-QWEN.md).

```sh
xcodebuild -project ios/DeepReader.xcodeproj -scheme DeepReaderiOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath artifacts/ios-free-qwen/DerivedData test

xcodebuild -project ios/DeepReader.xcodeproj -scheme DeepReaderiOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath artifacts/ios-free-qwen/DeepReader-1.1.0-4.xcarchive \
  -allowProvisioningUpdates archive
```

Choose your own development team when building a fork. Build numbers must be unique for uploads.
Generated models, signing material, recordings and archives are excluded from Git.

## Features

- Import PDF, EPUB, TXT and Markdown as local copies; originals remain unchanged.
- PDF text search, selection, persistent highlights and export of the annotated copy.
- EPUB spine-order text chapters; scripts and external content do not execute.
- Library search, ratings, finished state, saved reading position and an original bilingual sample.
- Explain a passage and ask follow-up questions using bundled Qwen, including in airplane mode.
- Book-only or general-knowledge scope. Neither mode searches the web; answers may be inaccurate.
- Adjustable sidebar on wide screens and a draggable, collapsible translucent floating assistant.
- Cancel inference, retain successful local history, delete records and explicitly share answers.
- Chinese and English interface; single-column library book rows, with no inserted ads.

Small models are best suited to simple explanations. Technical facts, calculations and complex reasoning
may be unreliable. Accuracy warnings appear beside answers and in Settings. There is no full-document
summary. Inputs and output length are bounded for device memory and latency; this is not a paid quota.
EPUB images/original typography, DRM, MOBI/AZW3, scanned-PDF OCR and cross-device sync are unsupported.

## Verification

The active test target includes document import/persistence/security and adaptive-layout regression tests,
plus actual bundled inference, follow-up, cancellation/history, scope prompts and missing-model failure.
Legacy provider settings can still decode, but cannot activate a remote service. iOS creates no cloud
credential client. Tests use generated documents, not the owner's private books or keys.
Historical tests and submissions are documented in [readiness](../docs/app-store/ios-readiness.md).

## Privacy and release data

Books, positions, highlights, settings and answers remain in the application container; system backups may
include them. Source/privacy/support links open only when selected. No user reading content is sent for
inference or developer analytics. The archived advertising prototype is no longer a supported iOS build.

For release experience, use App Store Connect → Analytics and filter to iOS. Review downloads,
product-page conversion, active devices, sessions, retention and crashes. Usage metrics include only
eligible users who opted to share analytics and may be unavailable below Apple's privacy thresholds.
They do not report readers' book text, questions, answers or a complete count of AI requests.
See [Apple app usage metrics](https://developer.apple.com/help/app-store-connect-analytics/engagement/app-usage/).

Original code is AGPL-3.0-or-later, ZIPFoundation and llama.cpp are MIT, and Qwen is Apache 2.0.
License texts and existing icon attribution ship in Settings. Support: baoshi.sun@icloud.com.
