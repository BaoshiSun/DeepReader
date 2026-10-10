# Mac App Store build

The `DeepReaderStore` scheme in `../DeepReader.xcodeproj` wraps the existing local Swift package in a native macOS application target. It builds arm64 and x86_64 and uses macOS 13 as its deployment target. No second reader implementation or remote package is used.

From the repository root:

```sh
python3 macos/prepare_app_store.py
xcodebuild -project macos/DeepReader.xcodeproj -scheme DeepReaderStore \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath artifacts/app-store/DeepReader-unsigned.xcarchive \
  -derivedDataPath artifacts/app-store/DerivedData CODE_SIGNING_ALLOWED=NO archive
```

This produces an **unsigned engineering archive, not an uploadable release**. The preparation script includes the explicit public source set, license texts and icon, and labels uncommitted source changes honestly. Run it again after source changes. Build 3 distinguishes this work from the build 2 GitHub preview.

For distribution, sign in to the approved Apple account in Xcode Settings → Apple Accounts, open the project, select the actual paid development team for `DeepReaderStore`, and confirm registration of `org.deepreader.macos`. Then archive with signing enabled and validate/distribute using Organizer → App Store Connect. Do not use Developer ID or the repository's DMG notarization script for a store upload. Team choice, certificates, provisioning and upload are not configured by this source tree; do not store private keys or account credentials here.

## Implemented and checked on 2026-10-10

- After the owner's explicit authorization, all three signing identities were created in the local login Keychain: Apple Development, Apple Distribution and Mac Installer Distribution. The Apple WWDR G3 intermediate was retrieved from [Apple PKI](https://www.apple.com/certificateauthority/), verified against system trust and added as an intermediate, without changing trust overrides. No private keys were exported.
- The source at commit `069a811` produced a signed universal archive and a successful local `app-store-connect` export. The exported `DeepReader.pkg` has a verified Mac Installer Distribution signature; its app has a verified Apple Distribution signature and an embedded provisioning profile. The local artifact is under `artifacts/app-store/export/`. This is not Apple server validation or an upload.
- After the owner explicitly confirmed the displayed App Store Connect Terms of Service (V100, 4 June 2018), acceptance completed and the Apps page opened. Creating the app with the name `DeepReader` was rejected because that name is already in use; a revised store display name is awaiting the owner’s choice. No app record or upload has been created yet.
- Native Xcode archive succeeded with Xcode 26.3 on macOS 15.7.4; binary contains arm64 and x86_64. This does not establish behavior on macOS 13 or Apple's acceptance of the upload.
- 27 offline XCTest cases passed, including denied consent for lookup, follow-up, full-document and history summaries, provider changes, bookmark recreation and corrupt bookmark recovery.
- App sandbox grants: outgoing connections, user-selected read/write files, app-scoped bookmarks. No broad home-folder access or incoming server entitlement.
- A local ad-hoc signed sandbox build opened a synthetic EPUB through the open panel, quit/restarted, reopened it from Books without another picker, and copied it into the selected rating archive folder. A synthetic PDF was also highlighted and saved in place using an OS-managed replacement directory, and a copy was saved to the authorized archive folder. These were real UI operations; no provider key or request was used.
- Bookmarks are stored locally beneath the application data directory. Security-scoped access remains alive for the reader and detached load/archive operations. Missing/revoked grants ask for a fresh selection.
- AI confirmation is per operation and names the provider, model, content scope and OpenRouter routing. Cancel is the default. Consent is not persisted, so an earlier acceptance never authorizes the next operation. Cancellation cannot recall bytes already transmitted.
- `PrivacyInfo.xcprivacy` declares file metadata access for user-selected documents (`3B52.1`) and app-container files (`C617.1`). PDF modification checks prevent overwriting externally changed files. No tracking is implemented. Data-collection declarations are deliberately not finalized pending provider retention/account-linkage review; this manifest must not be interpreted as “Data Not Collected”.

## Still required before submission

Apple server validation, upload and TestFlight; signed-identity Keychain checks; complete signed-build, export/cancellation and broader file-location tests; explicit old-profile import if migration is offered; approved public privacy policy and in-app link; actual provider smoke tests and private reviewer access; final screenshots, App Privacy and age-rating answers; private reviewer contact details; AGPL/LGPL App Store distribution compatibility review. Free pricing, ten intended storefronts and the public support address have been confirmed in `docs/app-store/listing.json`.

No license was changed. libmobi remains statically linked under LGPL-3.0-or-later; a source archive alone does not resolve all App Store licensing questions. See [readiness](../../docs/app-store/readiness.md).

Apple references: [file sandbox access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox), [required API reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
