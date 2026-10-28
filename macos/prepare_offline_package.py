#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Prepare the offline Swift package shared by GitHub and Mac App Store builds."""
from pathlib import Path
import hashlib
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'macos/.build/offline-package'


def prepare():
    dependencies = ROOT / 'ios/.build/local-qwen'
    model = dependencies / 'Qwen3-0.6B-Q4_K_M.gguf'
    framework = dependencies / 'build-apple/llama.xcframework'
    if not model.exists() or not framework.exists():
        raise SystemExit('Run python3 ios/prepare_local_model.py --dependencies-only before preparing the offline Mac build.')
    with model.open('rb') as stream:
        digest = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
        if digest.hexdigest() != 'cd47557a67d7e8f2891d98b5e1dbf2988544569fdf4f1bdb30e92b71aa61b548':
            raise SystemExit('Local model checksum mismatch.')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    # Replace only generated sources, preserving incremental build output.
    for name in ['Sources', 'Vendor', 'Tests', 'llama.xcframework']:
        path = OUTPUT / name
        if path.exists():
            shutil.rmtree(path)
    shutil.copytree(ROOT / 'macos/Sources', OUTPUT / 'Sources')
    shutil.copytree(ROOT / 'macos/Vendor', OUTPUT / 'Vendor')
    for name in ['Credentials.swift', 'QuestionCredits.swift']:
        (OUTPUT / 'Sources/DeepReaderCore' / name).unlink()
    shutil.copy2(ROOT / 'ios/Sources/LocalQwen.swift', OUTPUT / 'Sources/DeepReaderCore/LocalQwen.swift')
    shutil.copy2(ROOT / 'macos/AppStore/OfflineAI.swift', OUTPUT / 'Sources/DeepReaderCore/OfflineAI.swift')
    shutil.copy2(ROOT / 'macos/AppStore/OfflineCheck.swift', OUTPUT / 'Sources/DeepReaderDesktop/OfflineCheck.swift')
    shutil.copytree(ROOT / 'macos/AppStore/Tests', OUTPUT / 'Tests/OfflineStoreTests')
    shutil.copytree(framework, OUTPUT / 'llama.xcframework', symlinks=True)
    manifest = (ROOT / 'macos/Package.swift').read_text()
    manifest = manifest.replace('.macOS(.v13)', '.macOS("13.3")')
    manifest = manifest.replace('        .systemLibrary', '        .binaryTarget(name: "llama", path: "llama.xcframework"),\n        .systemLibrary', 1)
    manifest = manifest.replace('.target(name: "DeepReaderCore", dependencies: ["CArchive", "CMobi"])',
                                '.target(name: "DeepReaderCore", dependencies: ["CArchive", "CMobi", "llama"], swiftSettings: [.define("OFFLINE_QWEN")])')
    manifest = manifest.replace('.target(name: "DeepReaderDesktop", dependencies: ["DeepReaderCore"])',
                                '.target(name: "DeepReaderDesktop", dependencies: ["DeepReaderCore"], swiftSettings: [.define("OFFLINE_QWEN")])')
    manifest = manifest.replace('.testTarget(name: "DeepReaderTests", dependencies: ["DeepReaderCore", "DeepReaderDesktop"])',
                                '.testTarget(name: "OfflineStoreTests", dependencies: ["DeepReaderCore", "DeepReaderDesktop"])')
    (OUTPUT / 'Package.swift').write_text(manifest)
    return model


if __name__ == '__main__':
    prepare()
    print('Prepared offline Mac package.')
