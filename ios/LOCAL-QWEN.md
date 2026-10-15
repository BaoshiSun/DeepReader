# DeepReader — bundled offline Qwen builds

Separate development app (`org.deepreader.ios.local`, display name **DeepReader Local**).
The local development variant does not replace the App Store app or migrate its library.
The separate App Store variant below uses the existing store identity.

## Build

Requires Xcode and an Apple development signing team/device.

```sh
python3 ios/prepare_local_model.py
open ios/DeepReaderLocal.xcodeproj
```

For simulator testing, run `python3 ios/prepare_local_model.py --simulator` first.
This compiles the simulator slice from llama.cpp commit
`af0579c78a07a555d84830d01da7b61cfadbc7ef`; CMake 4.4.4 is installed into an
isolated build environment if needed. The official binary only includes devices and macOS.

Select `DeepReaderiOS` and your device, then Run. The existing team is YA66T3UWKU;
other developers must select their own team. The normal project is generated with
`python3 ios/prepare_project.py` and remains independent of llama and model weights.

The download script pins and SHA-256 verifies both artifacts before use:

- Qwen3-0.6B Q4_K_M, 484,219,808 bytes, quantized by LM Studio community.
  Revision `3334d820ab76652cf6e242d7c6302b10f0951f23`.
  SHA-256 `cd47557a67d7e8f2891d98b5e1dbf2988544569fdf4f1bdb30e92b71aa61b548`.
  https://huggingface.co/lmstudio-community/Qwen3-0.6B-GGUF
- Official llama.cpp Apple XCFramework b11624.
  SHA-256 `a6dd8a5ce837600544320a198f0550d74902f4fce543a00b4e157540235f03df`.
  https://github.com/ggml-org/llama.cpp/releases/tag/b11624

Qwen Apache 2.0 and llama MIT licenses are included in Settings → Open-source licenses.
Downloaded artifacts and generated local Xcode project are ignored by Git and excluded
from public source archives. This is a quantized derivative; model weights were not trained
or otherwise modified by DeepReader. Upstream model: https://huggingface.co/Qwen/Qwen3-0.6B.

## Behavior and privacy

- Model is bundled; no first-launch download, key, purchase, or server required.
- Explanation and follow-up use `LocalQwen` only; no remote fallback.
- StoreKit listeners are not started. Provider/key and purchase controls are hidden.
- Books and history are in this app's separate container; system backups may include them.
- External source/support links only open if explicitly selected.
- Book-only / general-knowledge scope still applies. Neither mode searches the web.
- No full-document summary in this experiment.
- Input takes up to 500 UTF-16 units of selection, 600 of nearby context, 300 of follow-up,
  and 250 of prior answer. Total prompt must fit 1536 tokens; overflow reports an error.
- Context 2048, output capped at 320 tokens, non-thinking Qwen chat template.
- CPU on simulator, Metal on physical devices. Four inference threads, 128-token prompt batches.
- Model/context released after each answer to reduce retained memory; the next question reloads it.
- Cancellation discards partial output and leaves prior saved history unchanged.
- Small model answers can be incorrect, especially technical details, calculations and world knowledge.

## Try it

1. Open **DeepReader Local**, import a short TXT/PDF/EPUB or open the sample.
2. Select a short sentence, choose Explain, then ask a follow-up.
3. Compare Book only with Add general knowledge.
4. Try airplane mode. No reading content should leave the device for AI.
5. Check cancellation, History and the resizable/floating assistant.

Automated tests run actual bundled inference, test follow-up/history and cancellation,
and verify missing-model failure and prompt scope/control-token escaping. Tests use synthetic text.
Tests emit runtime and output evidence into local Xcode test results. Simulator timings
are not measurements of iPhone performance.

## Verified build (2026-10-15)

- Release development build signed successfully; packaged as
  `artifacts/ios-local-qwen/DeepReader-Local-Qwen-0.6B.ipa`.
- App bundle approximately 477 MiB; IPA approximately 454 MiB.
- Three local tests passed on iPhone 17 simulator (iOS 26.3 runtime).
- All 23 existing iOS regression tests passed in the normal project.
- Actual local answer to “湿衣服晾晒后逐渐变干”: “选文说明：湿衣服晾晒后变干，是水分蒸发的过程。”
- General-knowledge follow-up “为什么有风时衣服干得更快？”: “因为风可以加速水分蒸发的过程，使湿衣服更快变干。”
- Simulator samples took approximately 5–11 seconds each after backend initialization.
  First Metal initialization took additional time. This is a smoke test, not a quality benchmark.

Physical-device verification also passed on iPhone 14 Pro, iOS 26.6.2:
all three local tests passed. Initial backend/Metal initialization took about 11 seconds;
after initialization, the short explanation completed in 1.52 seconds and the follow-up
in 1.12 seconds, including per-request model loading. These are two short samples, not
an overall performance guarantee. Cancellation restored the prior answer and history
survived a model reload. The separately signed release app was installed on the device.

## App Store variant 1.1.0 (3)

After preparing the model and framework, generate the offline store project:

```sh
python3 ios/prepare_project.py --store-qwen
xcodebuild -project ios/DeepReaderOfflineStore.xcodeproj -scheme DeepReaderiOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath artifacts/ios-offline-store/DeepReader-1.1.0-3.xcarchive \
  -allowProvisioningUpdates archive
```

This variant uses `org.deepreader.macos`, version 1.1.0 build 3, with
`DeepReaderLocalAI` and the `LOCAL_QWEN` compilation flag enabled. It includes
the model, accuracy disclaimer, offline sample and license texts. No API-key
entry, purchases or remote AI fallback is available. The regular generated
project retains separate online-development code and is not this submitted build.

The App Store archive and upload succeeded on 2026-10-15. Four simulator tests
passed, including actual offline explanations and iPhone/iPad store screenshots.
The physical-device results above describe the same offline engine in the local
variant; they are not a new physical-device recording of store build 3.
