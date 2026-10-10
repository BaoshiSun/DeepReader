# App Review notes — working draft

Do not submit this document unchanged. The sandboxed store candidate is separate from the older GitHub preview. Build 3 has been uploaded; build 4 removes direct Gemini support and adds the privacy-policy link. Complete the gates in readiness.md first. Private review contact details and access credentials belong in App Store Connect, never in this file or the public binary.

## Product explanation for the reviewer

DeepReader is a native macOS document and ebook reader. It reads PDF, EPUB, TXT, Markdown and DRM-free MOBI/KF8/AZW3. Its optional AI features explain selected text using nearby context, answer follow-ups, and summarize documents or locally saved reading records. The app has no DeepReader account system or developer-operated AI relay. Reading, highlights, ratings, local book lists and archive copies work without an AI API key.

AI requests authenticate with the user's selected third-party provider. Provider billing and quotas are separate. The app is free; store users may configure their own DeepSeek or OpenRouter API key. Provider charges and quotas are separate. Do not represent API credentials as an application activation code, and do not assume that BYOK automatically satisfies App Review payment rules.

## Private fields to complete in App Store Connect

- Actual candidate version, build number, tested macOS versions and source commit.
- Review contact name, email and telephone number.
- Review-only provider access, with sufficient quota and availability in the review region. Explain precisely where to enter it. Use a revocable, limited-budget credential supplied privately for review; do not embed it in source or the app. Revoke it after the review process when appropriate.
- Published privacy-policy URL and in-app location of the third-party consent controls.
- If Apple requests an authorized demonstration mode, explain it openly; do not silently replace live requests with fabricated results.
- A short screen recording if requested. The offline smoke screenshots are engineering evidence, not evidence of successful live AI calls.

## Reproduction steps

1. Launch the candidate on a clean macOS account. Open Setup and switch to English if necessary.
2. Open the attached synthetic reading sample with Command-O. Opening local files does not require signing into DeepReader.
3. Select “bank” in “The bank approved the loan.” Press Command-Shift-D. Verify the final consent flow identifies the recipient and explains the text being sent. Reject once to verify that no request is made, then authorize and retry using the privately supplied review access.
4. Ask “Why does it mean a financial institution here?” and press Command-Return. Confirm the response uses the source context and the conversation appears in History.
5. Highlight a selection; save PDF changes with Command-S. Reopen the document. For EPUB, change chapter, reopen, and verify locally saved highlights.
6. Resize the sidebar, float it, dock it and hide/show it with Command-Shift-A.
7. Assign a rating, mark the book Finished, and archive into a directory selected through the system picker. Restart the app and reopen the archived item through Books. Verify sandbox permissions survive restart, and handle a moved/deleted file or revoked access without a crash.
8. Prepare a document summary, inspect the request estimate, then generate it. Test a period summary only after records exist in that period. Summary uses extracted text; image-only pages have no OCR.
9. Delete the sample history record, remove the selected provider key, and verify new AI requests require configuration again.

## Test samples and known scope

Generate synthetic fixtures with `python3 macos/Tests/make_format_fixtures.py`. Use `garden.epub`, `garden.txt`, `garden.md`, `garden.mobi` and the smoke-test `sample.pdf`. These contain invented reading examples, not personal documents. The separately downloaded upstream libmobi samples are for engineering tests; review their licenses before any redistribution.

No DRM bypass, Kindle KFX, OCR, automatic cloud sync or scheduled background summaries. Ebook search is within the current chapter. Do not advertise these unsupported capabilities.

## Pre-submission evidence

Record fresh test results for the exact candidate, not just the earlier 1.2.1 preview. Cover Apple Silicon and Intel, the minimum supported macOS if it remains advertised, clean install, direct-version migration, bookmarks after restart, unavailable provider, cancellation, revoked credentials and insufficient quota. The public preview's CI passed 25 tests per architecture; those tests use offline transport and do not establish real provider availability.
