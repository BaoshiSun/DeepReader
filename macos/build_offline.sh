#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Build the offline GitHub edition. Signing/notarization uses distribute.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
out="${1:-$root/macos/dist-offline}"
[[ ! -e "$out" ]] || { echo 'Choose a new output directory.' >&2; exit 1; }
python3 ios/prepare_local_model.py --dependencies-only
python3 macos/prepare_offline_package.py
python3 macos/Tests/make_format_fixtures.py
package="$root/macos/.build/offline-package"
export MACOSX_DEPLOYMENT_TARGET=13.3
for arch in arm64 x86_64; do
    swift build --package-path "$package" -c release --arch "$arch" \
        --scratch-path "$root/macos/.build/offline-$arch" \
        -Xlinker -rpath -Xlinker '@executable_path/../Frameworks'
done
arm_binary="$(swift build --package-path "$package" -c release --arch arm64 --scratch-path "$root/macos/.build/offline-arm64" --show-bin-path)/DeepReader"
intel_binary="$(swift build --package-path "$package" -c release --arch x86_64 --scratch-path "$root/macos/.build/offline-x86_64" --show-bin-path)/DeepReader"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
app="$out/DeepReader.app"
resources="$app/Contents/Resources"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Frameworks" "$resources"
lipo -create "$arm_binary" "$intel_binary" -output "$app/Contents/MacOS/DeepReader"
chmod 755 "$app/Contents/MacOS/DeepReader"
ditto ios/.build/local-qwen/build-apple/llama.xcframework/macos-arm64_x86_64/llama.framework "$app/Contents/Frameworks/llama.framework"
python3 - "$app/Contents/Info.plist" <<'PY'
import plistlib, sys
from pathlib import Path
info = plistlib.loads(Path('macos/Info.plist').read_bytes())
info.update(DeepReaderAppStoreBuild=False, DeepReaderLocalAI=True,
            LSMinimumSystemVersion='13.3', LSApplicationCategoryType='public.app-category.books',
            CFBundleGetInfoString='DeepReader offline Qwen edition — AGPL-3.0-or-later')
Path(sys.argv[1]).write_bytes(plistlib.dumps(info))
PY
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
cp ios/.build/local-qwen/Qwen3-0.6B-Q4_K_M.gguf "$resources/"
cp ios/Resources/Local/Reading-Garden.txt "$resources/"
cp ios/Resources/Qwen-LICENSE.txt ios/Resources/llama-LICENSE.txt "$resources/"
cp macos/AppStore/PrivacyInfo.xcprivacy "$resources/"
cp LICENSE-AGPL-3.0.txt "$resources/LICENSE.txt"
cp THIRD-PARTY-NOTICES.md macos/README.md "$resources/"
python3 tools/public_release.py --source-zip
python3 - "$resources/Source.zip" <<'PY'
import shutil, sys
sys.path.insert(0, 'tools')
import public_release
shutil.copy2(f'DeepReader-v{public_release.VERSION}-source.zip', sys.argv[1])
PY
git rev-parse HEAD > "$resources/SOURCE-COMMIT.txt"
if [[ -n "$(git status --porcelain)" ]]; then
    echo 'Development build: working tree changes included.' >> "$resources/SOURCE-COMMIT.txt"
fi
iconset="$out/DeepReader.iconset"
mkdir "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" assets/DeepReader-green.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" assets/DeepReader-green.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$resources/DeepReader.icns"
rm -rf "$iconset"
codesign --force --sign - "$app/Contents/Frameworks/llama.framework"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/DeepReader" -verify_arch arm64 x86_64
lipo "$app/Contents/Frameworks/llama.framework/llama" -verify_arch arm64 x86_64
mkdir "$out/smoke"
(cd "$root/macos" && "$app/Contents/MacOS/DeepReader" --smoke-test "$out/smoke")
"$app/Contents/MacOS/DeepReader" --offline-check > "$out/offline-check.txt" 2>&1
grep -q 'OFFLINE_PACKAGED_QA_PASS' "$out/offline-check.txt"
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/DeepReader-v${version}-macos-universal.zip"
cp "$resources/Source.zip" "$out/DeepReader-v${version}-macos-source.zip"
(cd "$out" && shasum -a 256 ./*.zip > SHA256SUMS.txt)
echo "Offline development app built and tested: $app"
echo 'Ad-hoc signed only. Use distribute.sh and Apple notarization before publishing.'
