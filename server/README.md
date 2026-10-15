# DeepReader ordinary-question service

Unreleased implementation, 2026-10-15. The service is **not deployed**. No real DeepSeek key has been added or used. The product must be configured and approved in App Store Connect before selling it. Local tests do not certify end-to-end StoreKit or production readiness.

## App Store Connect preparation

Saved on 2026-10-15 in [App Store Connect](https://appstoreconnect.apple.com/apps/6821368213/distribution/iaps/6822903255):

- App: `6821368213`, DeepReader: Read with AI.
- Consumable Apple ID: `6822903255`, reference name `500 Ordinary AI Questions`.
- Product ID: `org.deepreader.questions.500`; base storefront China mainland, CNY 6.00.
- Availability: China mainland, Hong Kong, Macao, Taiwan, Saudi Arabia, UAE, Qatar, Kuwait, Bahrain and Oman. Automatic availability in future storefronts is disabled.
- Saved localizations: Simplified Chinese `500 次普通问答` and US English `500 Ordinary Questions`.
- Current status: draft / Ready to Submit. **Not submitted for review or on sale.** The first consumable must accompany a new app version.

Before submission: deploy and validate both gateways; complete bank/tax requirements; update privacy labels and public policy with hosting/retention details; increment the app build/version; capture the real purchase screen for IAP review; attach this product to the new submission; test purchase, interrupted delivery, cross-device balance, refunds and real answers on supported physical devices. Do not upload the unconfigured preview screenshot as evidence of a working purchase flow.

## Product contract

- Consumable `org.deepreader.questions.500`: 500 successful ordinary explanations/follow-ups. China mainland base price: **CNY 6**; other storefronts use Apple's corresponding prices. The app displays `Product.displayPrice`, never a hard-coded currency.
- No subscription, expiration, personal-key input, model picker, or document-summary allowance in the Apple store edition. Non-store desktop editions retain existing BYOK support.
- DeepSeek Flash, thinking disabled, maximum 500 output tokens. The client selects a bounded excerpt and preserves the current question; the server independently rejects source text over 6,000 UTF-8 bytes. Neither arbitrary URLs/models nor raw chat-message arrays are accepted.
- One credit reserved atomically per request; failure returns it exactly once. Successful output remains charged even if delivery is interrupted. It can be recovered within 24 hours without another debit.
- Recovery uses the latest server-accepted request for the authenticated wallet, including across devices. An extra attempt rejected while a request is pending cannot overwrite or hide the original answer.
- Safety limits: one active generation per wallet, 20 authenticated operations/minute, 60 incoming requests/minute per peer, 100 attempted generations/wallet/day, and initially 1,000 attempted generations/server/day. Failures count toward safety limits to prevent unlimited free retries. Limits reset at UTC midnight. These are request limits, **not a guaranteed currency spending cap**; keep a separate limited-balance DeepSeek project/key and billing alerts. Change the in-app daily-limit disclosure together with the server value.

## Identity, accounting and refunds

The app sends a verified `AppTransaction.jwsRepresentation` over HTTPS as a bearer proof. Apple's official server library validates the Apple certificate chain online, signature, environment, bundle ID and app ID. The stable `appTransactionId` identifies the same App Store account/app across reinstalls and devices; it is hashed before storage. The app does not collect an Apple email or password. Proofs are sensitive bearer credentials: never log headers or put them in URLs. This is not device attestation; a stolen proof could spend that wallet's credits. The developer API key is never returned to the client.

A deterministic UUID `appAccountToken` is supplied with StoreKit purchases. The server requires the transaction's verified app identity, product, quantity=1 and account token to match. Transaction IDs are unique in the ledger: repeated delivery grants no extra credits. The app calls `finish()` only after server acknowledgment; unfinished purchases retry through StoreKit updates and refresh. Finished consumables are not reconstructed from `currentEntitlements`: the durable server wallet is the source of truth, so backups are essential.

Configure App Store Server Notifications V2 at `/v1/apple-notifications`. Signed REFUND/REVOKE events debit the original 500 credits once; spent credits may leave an internal negative balance, displayed as zero. REFUND_REVERSED reverses that adjustment. Timestamp ordering and refund tombstones prevent replay of stale purchases and out-of-order events. Test duplicate events and refunded-before-redemption purchases in Sandbox before release. Apple notifications and online signature checks must remain reachable; monitor notification failures and reconcile missed refunds through Apple's transaction APIs/support before reopening sales after an outage.

Production and Sandbox **must use separate deployments, databases, encryption keys, DeepSeek budget keys, and HTTPS hosts**. Only the corresponding Apple environment is accepted; never fall back from failed Production verification to Sandbox. Sandbox users do not pay, so keep its DeepSeek balance and limits very small. Local Xcode StoreKit signatures are intentionally rejected by the real server.

## Deployment

Recommended initial host (not purchased): Alibaba Cloud international Simple Application Server, China (Hong Kong), Linux, 2 vCPU / 2 GiB RAM / 40 GiB system disk. The [official product page](https://www.alibabacloud.com/tc/product/swas?_p_lc=1) displayed USD 8/month on 2026-10-15; verify account-specific checkout, tax, renewal and traffic terms before buying. Start with one month. One host can run separate production and sandbox containers, volumes, credentials and subdomains; it remains a single-host availability risk. Buy one ordinary domain and use two subdomains, with automated free TLS. Budget external database backups separately. Capacity and mainland/Gulf network latency still require measurement. Hong Kong hosting does not resolve the app's China-market AI/compliance review requirements.

Use a persistent single-host service. SQLite uses WAL and `BEGIN IMMEDIATE`; do not place this database on shared network storage or run ephemeral replicas. Scale by moving the ledger to a transactional managed database before adding multiple hosts.

1. Obtain a server/managed container with persistent storage and two HTTPS domains (production and sandbox). No server has been selected or purchased for this implementation.
2. Download Apple root `.cer` files from [Apple PKI](https://www.apple.com/certificateauthority/) to a read-only `certs` directory. Trust only those downloaded from Apple's official site; never certificates supplied by a client.
3. Copy `example.env` to an ignored local `.env`, mode 600. Enter your **dedicated** DeepSeek API key on the server, not in chat, Git, the app, logs, or build arguments. Generate `ANSWER_ENCRYPTION_KEY` with `Fernet.generate_key()` and save it securely outside the database. Never rotate it without migrating/deleting cached answer ciphertext.
4. Build this Dockerfile. Mount persistent `/app/data` writable by UID 10001, and `/app/certs` read-only. Publish port 8000 only on loopback, behind an HTTPS reverse proxy. Supply the environment through the hosting secret manager or `--env-file`; do not bake it into the image.
5. At the proxy, cap request bodies at 48 KB, allow Apple proof headers up to 24 KB, impose connection/read timeouts and an edge rate limit/WAF. Disable request-body and Authorization-header logging. If preserving client IPs, trust **only the exact proxy address** in Uvicorn; its default here ignores forwarded headers, so requests otherwise share the proxy's rate bucket. Never trust `X-Forwarded-For` from the open Internet.
6. Configure notifications in App Store Connect, test with Sandbox, and back up the SQLite database using SQLite's backup API (not a blind copy of a live WAL file). Test restoring the backup with the answer-encryption key. Loss of the ledger loses remaining consumable balances.
7. Before generating Apple build resources, set `DEEPREADER_GATEWAY_URL=https://<production-host>` and `DEEPREADER_SANDBOX_GATEWAY_URL=https://<sandbox-host>`. Run `python3 ios/prepare_project.py` or `python3 macos/prepare_app_store.py`. These public base URLs go in the plist; **keys never do**. Blank configuration disables purchase/request operations. Use iOS Release configuration (`org.deepreader.macos`) for the existing store product; the Debug bundle (`org.deepreader.ios`) is a separate identity and cannot redeem that product.
8. Finish paid-app banking/tax setup, update store metadata/privacy disclosures, attach the IAP to the submission, and perform physical-device Sandbox/TestFlight QA. Do not submit this as ready until both gateways and the approved product work.

For a non-container deployment, create a virtual environment, install `requirements.txt`, set the server environment and run `uvicorn app:production_app --factory --host 127.0.0.1 --port 8000 --workers 1 --no-access-log`. Put TLS in front; do not expose the unencrypted listener.

## Data handling

Request source text is forwarded in memory, never stored in the ledger. It still reaches DeepSeek and follows DeepSeek's policy. A SHA-256 request fingerprint detects mismatched idempotency keys. The ledger retains pseudonymous wallet IDs, transaction IDs, balances and request timestamps/state for accounting and abuse controls. Generated answers are encrypted with a server-held key for recovery and cleared after approximately 24 hours (cleanup interval 60 seconds); the in-app clear action clears them immediately. Temporary hashed-IP rate buckets are deleted after an hour. No application access logs, raw receipts, bearer proofs, or provider error bodies are logged. Configure equivalent policies for proxy/hosting backups and logs. Accounting records need a retention/deletion policy appropriate to the deployed business; document that policy and the hosting location before launch.

## Offline verification

```sh
cd server
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m pytest -q
```

Tests use injected fake Apple/provider adapters, never a real key or API charge. Production has no test-verification switch. Test signature failures, receipt replay, owner mismatch, last-credit concurrency, upstream failures, refunds/reversals, budget caps, response recovery, and crash cleanup. Real sandbox signed transactions, Apple notifications, device verification, cross-device balance recovery, HTTPS performance, load testing, and a live DeepSeek request remain deployment acceptance steps.

Latest local verification: 18 backend tests, 39 macOS tests and 23 iOS simulator tests passed. The unconfigured iOS credit screen was rendered and inspected; it does not offer a purchase button before the gateway and StoreKit product are available. The public-source audit also passed. Docker deployment and real StoreKit purchases have not been tested.

Sources: [Apple server library](https://github.com/apple/app-store-server-library-python), [appTransactionID](https://developer.apple.com/documentation/storekit/apptransaction/apptransactionid), [StoreKit purchase lifecycle](https://developer.apple.com/documentation/storekit/offering-completing-and-restoring-in-app-purchases/).
