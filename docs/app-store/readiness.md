> Current macOS status — verified 2026-10-30 (Asia/Riyadh): **1.3.1 (9) is Ready for Distribution**, with `READY_FOR_SALE`, `downloadable=true` and automatic release after approval confirmed by App Store Connect. It remains free, fully on-device and without ads. Earlier status/privacy declarations below are historical. This check does not update iOS status.

## macOS publication — verified 2026-10-30

The existing approved build is downloadable; no manual release request or replacement binary is needed. Chinese and English promotional text emphasizes free on-device AI and reading/Q&A without a network, including flights, off-grid travel and outages. Books must be stored locally; cloud-only files should be downloaded before going offline. Installing/updating the app and user-initiated external links still require a connection. The bundled model needs no online activation or first-run download and does not search for real-time information.

Only the editable promotional text is updated in App Store Connect; the approved descriptions, screenshots, binary, availability and iOS metadata are retained. [App Store listing](https://apps.apple.com/app/id6821368213). GitHub macOS 1.3.2 is separately available with a Developer ID signature and accepted Apple notarization. The Release notes and repository documentation describe the same offline use cases.

## macOS resubmission — 2026-10-23

The owner chose to keep native macOS free and without advertising. Existing build **1.3.1 (9)** was reused unchanged; Apple reports VALID. No new binary or SDK was added. The archive's earlier QA below remains the applicable test record; no new physical-device test is claimed for this metadata-only resubmission.

- App Store Connect confirms **Waiting for Review**. Submission ID: `a27a00be-9cc0-4190-95a8-46a09cf4c64d`; build ID: `a1b90523-77f2-481a-97e3-5dad22aa9b38`. [Open submission](https://appstoreconnect.apple.com/apps/6821368213/distribution/reviewsubmissions/details/a27a00be-9cc0-4190-95a8-46a09cf4c64d).
- Free pricing, all 175 selected storefronts and automatic release after approval are retained. Submission does not mean approval or publication.
- Chinese/English descriptions and screenshots continue to describe the offline, ad-free Mac app. Review Notes now identify the unchanged resubmission and explain the platform distinction: shared App Privacy disclosures include the optional iOS advertising SDK; Mac build 9 has no ads, advertising SDK or app data collection. The shared privacy policy explicitly separates these versions. No privacy declaration was removed for iOS.
- Google Mobile Ads' iOS SDK does not support this native macOS project; no iOS advertising unit was reused. The owner selected resubmission without ads after this limitation was explained.
- Local proof is in `artifacts/macos-resubmit-2026-10-23/`: `submission-confirmation.png`, `waiting-for-review.png`, and `submission-result.json` (ignored by Git).

## Historical withdrawal — 2026-10-20

At the owner's request, iOS 1.1.0 (4) and macOS 1.3.1 (9) were withdrawn from review (DEVELOPER_REJECTED). The later submissions above supersede that status.

## Historical macOS offline submission — 2026-10-20

Version 1.3.1 (9) replaces remote AI with bundled Qwen3 0.6B Q4_K_M. Free; no API keys, purchases, ads or quotas. Minimum macOS 13.3; arm64 and x86_64. Three local-engine tests and 39 direct-edition regression tests passed. The signed sandboxed universal archive passed real inference, follow-up, cancellation, PDF reading and bundled TXT opening on Apple M4 / macOS 15.7.4. Intel hardware was not tested. Four actual Chinese/English screenshots and offline descriptions replaced the old store metadata. App Privacy now declares Data Not Collected for the offline App Store editions. Apple processed build 9 successfully and it replaced build 8. The existing rejection was resolved and resubmitted at 13:35 Riyadh on 2026-10-20; both version and submission report WAITING_FOR_REVIEW. A reply explaining the Guideline 3.1.1/5 changes was sent to App Review. This is submission, not approval. iOS 1.1.0 (4) remains WAITING_FOR_REVIEW. Existing 175-storefront availability and automatic release are retained.

All older status and remote-provider instructions below are historical and superseded by this offline candidate.

# Mac App Store readiness and acceptance

Assessment updated: 2026-10-10. Unchecked items remain incomplete or require final signed-build verification. Implemented subset: native Xcode universal archive, sandbox entitlements/bookmarks, per-operation AI consent and file-metadata API reason declarations. See [build and validation details](../../macos/AppStore/README.md). A local sandbox EPUB opened, reopened after process restart, and archived successfully; synthetic PDF in-place highlight saving and Save Copy also succeeded; 27 offline tests passed. Build 1.2.1 (3) uploaded successfully on 2026-10-10; replacement build 4 uploaded successfully and completed Apple processing. No App Review submission has occurred.

## Release channels

Developer ID distribution retains the existing native app and adds Hardened Runtime, a trusted signature and Apple notarization. App Store distribution additionally needs sandboxed behavior, an Apple Distribution build/provisioning workflow, metadata and review. Developer ID certificates do not replace App Store distribution certificates. A notarized DMG is not an App Store submission.

## Engineering gates

- [x] Create the macOS app target/archive configuration in full Xcode, using the existing Swift and C sources without adding another runtime. Export with the approved team's Apple Distribution signing identity and a distribution provisioning profile. Local package/signature validation passed; build 4 completed Apple processing. This is not App Review approval.
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

Final App Privacy answers depend on Apple's definition of collection, provider retention and account linkage. Do not automatically select “Data Not Collected” because the maintainer has no server. The App Store Connect questionnaire has now been completed as recorded below; this does not resolve separate regional permit or license questions.

Provider recheck on 2026-10-10: [OpenRouter Terms, section 2](https://openrouter.ai/terms) require users to be at least 18. Removing direct Gemini alone does not remove that age constraint from the two-provider candidate. The owner chose to remove OpenRouter as well; replacement build 5 supports only DeepSeek. This does not by itself establish the final age rating. [DeepSeek's current API guide](https://api-docs.deepseek.com/) lists `deepseek-flash` and `deepseek-v4-pro`; this verifies the model names, not a successful authenticated request. The English Open Platform terms and privacy policy were successfully retrieved later on 2026-10-10. The Open Platform terms permit downstream API integration subject to the developer’s end-user privacy and consent duties. The privacy policy describes account linkage, input retention, technical/usage logs and IP-derived coarse location, and does not provide a universal zero-retention/no-training guarantee. See the [Open Platform terms](https://cdn.deepseek.com/policies/en-US/deepseek-open-platform-terms-of-service.html) and [privacy policy](https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html).

## License and ownership gate

- [ ] Review original Mac code under AGPL-3.0-or-later against the final distribution agreement/EULA and any imposed restrictions. Identify the rights holder(s) before considering any alternative license or exception.
- [ ] Review statically linked libmobi under LGPL-3.0-or-later, especially recipients' ability to modify and relink, source provision and installation information. An original-code relicensing decision does not relicense libmobi.
- [ ] Preserve the Alex / CC BY 3.0 icon attribution and modification notice. Decide whether a distinct icon is desired before final branding; do not remove attribution from the existing one.
- [ ] Confirm provider service terms permit the proposed integration and business model. No legal compatibility conclusion or blanket “App Store approved” claim is made here.

The Mac binary does not link the Windows SumatraPDF/MuPDF engine. Assess the Mac dependency graph rather than assuming every Windows dependency is in the Mac app. See [third-party notices](../../THIRD-PARTY-NOTICES.md) and the embedded license texts. Obtain a qualified license review if compatibility remains unresolved.

## Store assets and owner decisions

- [x] Confirm free/paid pricing, BYOK design, countries/regions and the actual seller name; complete paid agreements/banking/tax only if applicable. Free pricing and the exact ten storefronts are saved in App Store Connect.
- [x] Confirm available display name, Bundle ID, copyright owner, support URL and a public privacy-policy URL. The record is DeepReader: Read with AI, org.deepreader.macos, Apple ID 6821368213; operator and original-code owner Baoshi Sun.
- [x] Private review contact and review access are saved in App Store Connect. Credential validity and quota remain untested at the owner’s request.
- [x] Capture accurate final-build screenshots in Chinese and English. Apple's current Mac sizes are 1280×800, 1440×900, 2560×1600 or 2880×1800 (16:10); verify again before upload.
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

## App Store Connect completion — 2026-10-10

- Version 1.2.1 is associated with DeepSeek-only build 5. Review contact and private review access are saved in Apple’s backend. The owner declined local use of the review key; no authenticated provider test was performed.
- Content Rights: saved “Yes, this app has the necessary rights to its third-party content.” This describes licensed bundled content and does not establish AGPL/LGPL compatibility with the App Store agreement.
- Age questionnaire: no built-in restricted content, social features, advertising, gambling or unrestricted browser. Calculated 4+; a conservative 16+ override was selected pending any owner preference change. Apple maps earlier-than-26 operating systems to 17+ with regional exceptions.
- App Privacy: published. Other User Content: App Functionality, Analytics, Other Purposes. User ID, Other Usage Data, Other Diagnostic Data: App Functionality and Analytics. Coarse Location: App Functionality. All five are linked to the provider account; none is declared used for tracking. These declarations include direct DeepSeek API processing, not developer-operated analytics or GPS collection.
- Store screenshots use the exact archived build 5 opening the original garden EPUB fixture. They contain no generated AI answer or credential. Full-window captures are proportionally scaled and padded to 2560×1600 without removing controls; originals and upload PNGs remain in ignored artifacts/app-store/screenshots.

Both Chinese (Simplified) and English (U.S.) uploads completed with one 2560×1600 screenshot each. Apple’s Add for Review validation succeeded: version 1.2.1 (5) is Ready for Review and appears in Draft Submission as Item Ready to Submit. The final Submit for Review action has not been performed.

## Unreleased multi-provider changes — 2026-10-12

New development source supports 12 named providers plus a custom compatible endpoint. No submitted binary or App Store metadata was changed by this development work. Before a new submission: complete real-account checks for intended providers and regions; review Gemini/OpenRouter 18+ terms and overall audience; update store descriptions, reviewer instructions, screenshots, age rating and privacy labels for actual recipients/downstream routing. The app’s age confirmation is only one control, not a legal compliance determination. Windows CI compiled the native AI panel and passed 121 core checks; the legacy helper compiled and passed 67 offline checks. Complete Windows packaging and manual GUI verification remain. See the root README and privacy-policy supplement.
