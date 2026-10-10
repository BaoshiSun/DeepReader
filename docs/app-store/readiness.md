# Mac App Store readiness and acceptance

Assessment updated: 2026-10-10. Unchecked items remain incomplete or require final signed-build verification. Implemented subset: native Xcode universal archive, sandbox entitlements/bookmarks, per-operation AI consent and file-metadata API reason declarations. See [build and validation details](../../macos/AppStore/README.md). A local sandbox EPUB opened, reopened after process restart, and archived successfully; synthetic PDF in-place highlight saving and Save Copy also succeeded; 27 offline tests passed. Build 1.2.1 (3) uploaded successfully on 2026-10-10; replacement build 4 uploaded successfully and completed Apple processing. No App Review submission has occurred.

## Release channels

Developer ID distribution retains the existing native app and adds Hardened Runtime, a trusted signature and Apple notarization. App Store distribution additionally needs sandboxed behavior, an Apple Distribution build/provisioning workflow, metadata and review. Developer ID certificates do not replace App Store distribution certificates. A notarized DMG is not an App Store submission.

## Engineering gates

- [x] Create the macOS app target/archive configuration in full Xcode, using the existing Swift and C sources without adding another runtime. Export with the approved team's Apple Distribution signing identity and a distribution provisioning profile. Local package/signature validation passed; server validation remains outstanding.
- [ ] Enable App Sandbox with outgoing network and user-selected read/write access. Decide the bookmark scope and add only the entitlements the implementation uses.
- [ ] Replace plain-path persistence with security-scoped access for reopened documents and archive destinations. Balance start/stop access during asynchronous work, recover stale bookmarks, and prompt for renewed access when needed.
- [ ] Test PDF in-place saves, Save Copy, ebook extraction to temporary storage, exported history and rating-folder archive copies under sandbox restrictions. Preserve originals and handle same-name collisions.
- [ ] Migrate direct-version settings, history, books and highlights by an explicitly authorized import. Test Keychain access under the final signing identity; do not promise existing credentials automatically migrate.
- [ ] Show an in-app policy link and explicit third-party AI consent before sending personal data. Name the selected provider and disclose OpenRouter downstream routing. Explain selection versus whole-document/period-summary scope, support refusal and revocation, and reconsider consent when recipients or terms change.
- [ ] Confirm model IDs and real provider behavior close to submission. Existing tests use mocked responses; list entries are not an assertion of current provider availability.
- [ ] Audit required-reason APIs and SDK privacy manifests; populate PrivacyInfo.xcprivacy only with actual reasons/data behavior. An empty “no data collected” manifest is not a substitute for an audit.
- [ ] Ensure the App Store variant uses the store for updates and does not direct users to replace it with a GitHub build.

Code ownership: file selection and PDF saves are in `ReaderWindow.swift`; persisted paths and archives in `LibraryStore.swift` / `Models.swift`; AI requests in `AIClient.swift`; orchestration, history and consent integration in `ReaderModel.swift`; settings UI in `Sidebar.swift`.

## Privacy declaration worksheet

| Information | Current behavior | App Store declaration work |
| --- | --- | --- |
| Local paths, book metadata, highlights | Stored on device | Re-check sandbox import/export; local-only storage is distinct from transmission |
| Selected text, context, follow-ups, extracted text | Sent to selected AI service | Assess User Content / Other User Content and any personal information in documents |
| Period records | Sends timestamps, titles, selections, answers | Include filenames that appear as titles; do not claim no metadata ever leaves the device |
| Provider credentials | Keychain locally; sent to provider for authentication | Evaluate provider account linkage; never claim requests are anonymous |
| IP/request metadata | Visible to API provider as part of network communication | Confirm provider collection and retention |
| Analytics and ads | No embedded SDK in current code | Re-evaluate if any dependency or business model changes |

Final App Privacy answers depend on Apple's definition of collection, provider retention and account linkage. Do not automatically select “Data Not Collected” because the maintainer has no server. No final questionnaire answers, age rating, encryption exemption or regional compliance declarations are made by these drafts.

## License and ownership gate

- [ ] Review original Mac code under AGPL-3.0-or-later against the final distribution agreement/EULA and any imposed restrictions. Identify the rights holder(s) before considering any alternative license or exception.
- [ ] Review statically linked libmobi under LGPL-3.0-or-later, especially recipients' ability to modify and relink, source provision and installation information. An original-code relicensing decision does not relicense libmobi.
- [ ] Preserve the Alex / CC BY 3.0 icon attribution and modification notice. Decide whether a distinct icon is desired before final branding; do not remove attribution from the existing one.
- [ ] Confirm provider service terms permit the proposed integration and business model. No legal compatibility conclusion or blanket “App Store approved” claim is made here.

The Mac binary does not link the Windows SumatraPDF/MuPDF engine. Assess the Mac dependency graph rather than assuming every Windows dependency is in the Mac app. See [third-party notices](../../THIRD-PARTY-NOTICES.md) and the embedded license texts. Obtain a qualified license review if compatibility remains unresolved.

## Store assets and owner decisions

- [ ] Confirm free/paid pricing, BYOK design, countries/regions and the actual seller name; complete paid agreements/banking/tax only if applicable.
- [ ] Confirm available display name, Bundle ID, copyright owner, support URL and a public privacy-policy URL.
- [ ] Fill private review contact and review access in App Store Connect; provide sufficient quota, not a production shared key.
- [ ] Capture accurate final-build screenshots in Chinese and English. Apple's current Mac sizes are 1280×800, 1440×900, 2560×1600 or 2880×1800 (16:10); verify again before upload.
- [ ] Suggested scenes: contextual PDF explanation; EPUB chapter/highlight; floating sidebar; ratings/book list; summary preview. Use invented sample text and no personal credentials.
- [ ] Existing smoke snapshots contain explicitly labeled offline answers and non-store dimensions. They are reference material only; do not stretch, crop away functionality, or present them as live API evidence.
- [ ] Verify icon assets inside the signed app and archive, accessibility, light/dark appearance, keyboard operation, minimum window size and text clipping.
- [ ] Test through TestFlight and attach the exact build to the reviewed metadata. Resolve upload validation and review feedback before publication.

## Sources consulted

- [App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) — 2.4.5, 3.1, 5.1 and 5.2
- [App Privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [GNU license FAQ](https://www.gnu.org/licenses/gpl-faq.en.html)
