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

This produces an **unsigned engineering archive, not an uploadable release**. The preparation script includes the explicit public source set, license texts and icon, and labels uncommitted source changes honestly. Run it again after source changes. Build 5 supports only DeepSeek in the store edition; build 4 disabled direct Gemini access and added the public privacy-policy link; build 3 was the first uploaded engineering build and build 2 was the GitHub preview.

For distribution, sign in to the approved Apple account in Xcode Settings → Apple Accounts, open the project, select the actual paid development team for `DeepReaderStore`, and confirm registration of `org.deepreader.macos`. Then archive with signing enabled and validate/distribute using Organizer → App Store Connect. Do not use Developer ID or the repository's DMG notarization script for a store upload. Team choice, certificates, provisioning and upload are not configured by this source tree; do not store private keys or account credentials here.

## Implemented and checked on 2026-10-10

- After the owner's explicit authorization, all three signing identities were created in the local login Keychain: Apple Development, Apple Distribution and Mac Installer Distribution. The Apple WWDR G3 intermediate was retrieved from [Apple PKI](https://www.apple.com/certificateauthority/), verified against system trust and added as an intermediate, without changing trust overrides. No private keys were exported.
- The source at commit `069a811` produced a signed universal archive and a successful local `app-store-connect` export. The exported `DeepReader.pkg` has a verified Mac Installer Distribution signature; its app has a verified Apple Distribution signature and an embedded provisioning profile. The local artifact is under `artifacts/app-store/export/`. This is not Apple server validation or an upload.
- After the owner explicitly confirmed the displayed App Store Connect Terms of Service (V100, 4 June 2018), acceptance completed and the Apps page opened. Creating the app with the name `DeepReader` was rejected because that name is already in use; the owner selected `DeepReader: Read with AI`, which was created successfully (Apple ID `6821368213`). Build 1.2.1 (3) uploaded successfully via Xcode. Pricing is free; exactly the ten requested storefronts are available on release. The app has not been submitted for review.
- Native Xcode archive succeeded with Xcode 26.3 on macOS 15.7.4; binary contains arm64 and x86_64. This does not establish behavior on macOS 13 or Apple's acceptance of the upload.
- 28 offline XCTest cases passed, including rejection of restored Gemini settings before creating a store-build request, including denied consent for lookup, follow-up, full-document and history summaries, provider changes, bookmark recreation and corrupt bookmark recovery.
- App sandbox grants: outgoing connections, user-selected read/write files, app-scoped bookmarks. No broad home-folder access or incoming server entitlement.
- A local ad-hoc signed sandbox build opened a synthetic EPUB through the open panel, quit/restarted, reopened it from Books without another picker, and copied it into the selected rating archive folder. A synthetic PDF was also highlighted and saved in place using an OS-managed replacement directory, and a copy was saved to the authorized archive folder. These were real UI operations; no provider key or request was used.
- Bookmarks are stored locally beneath the application data directory. Security-scoped access remains alive for the reader and detached load/archive operations. Missing/revoked grants ask for a fresh selection.
- AI confirmation is per operation and names the provider, model, content scope and OpenRouter routing. Cancel is the default. Consent is not persisted, so an earlier acceptance never authorizes the next operation. Cancellation cannot recall bytes already transmitted.
- `PrivacyInfo.xcprivacy` declares file metadata access for user-selected documents (`3B52.1`) and app-container files (`C617.1`). PDF modification checks prevent overwriting externally changed files. No tracking is implemented. Data-collection declarations are deliberately not finalized pending provider retention/account-linkage review; this manifest must not be interpreted as “Data Not Collected”.

- Source commit `91cb650` produced build 1.2.1 (4). Xcode reported upload success, and App Store Connect finished processing it. After checking the code uses Apple OS HTTPS/Keychain/CryptoKit only (libmobi is built without USE_ENCRYPTION), the export questionnaire was saved as none of the listed non-OS algorithms; TestFlight now shows `Ready to Submit`, not an App Review approval. Chinese and English privacy-policy URLs and review contact information were saved. The private telephone number is stored only in App Store Connect.
- The first local launch of the development-signed build 4 archive waited in macOS sandbox initialization (`_libsecinit_appsandbox`) before application code and was stopped. A later launch on 2026-10-10 reached the reader window successfully, without changing container data or security settings. The running executable was verified as the build 4 archive; Settings showed only DeepSeek and OpenRouter and the public privacy-policy link. The cause of the earlier wait is unconfirmed. The native file picker then could not be observed or controlled through the automation interface; process samples show the app in `NSSavePanel.runModal` and the panel service in its event loop. This is a partial signed-build UI check, not a completed file workflow or TestFlight test.

## Still required before submission

Upload and TestFlight testing of replacement build 5; signed-identity Keychain checks; complete signed-build, export/cancellation and broader file-location tests; explicit old-profile import if migration is offered; verify the public privacy page renders; actual provider smoke tests and private reviewer access; final screenshots, App Privacy and age-rating answers; AGPL/LGPL App Store distribution compatibility review. Free pricing, ten intended storefronts and the public support address have been confirmed in `docs/app-store/listing.json`. Review contact information is already saved privately in App Store Connect; the owner is preparing review-only API access there. Preserve those private notes when changing other metadata.

No license was changed. libmobi remains statically linked under LGPL-3.0-or-later; a source archive alone does not resolve all App Store licensing questions. See [readiness](../../docs/app-store/readiness.md).

Apple references: [file sandbox access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox), [required API reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons), [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
