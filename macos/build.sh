#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail
cd "$(dirname "$0")"
root="$(cd .. && pwd)"
out="$root/macos/dist"
mkdir -p "$out"
export MACOSX_DEPLOYMENT_TARGET=13.0
for arch in arm64 x86_64; do
    swift build -c release --arch "$arch" --scratch-path ".build/$arch"
done
arm_binary="$(swift build -c release --arch arm64 --scratch-path .build/arm64 --show-bin-path)/DeepReader"
intel_binary="$(swift build -c release --arch x86_64 --scratch-path .build/x86_64 --show-bin-path)/DeepReader"
stage="$(mktemp -d "$out/package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/DeepReader.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
lipo -create "$arm_binary" "$intel_binary" -output "$app/Contents/MacOS/DeepReader"
chmod 755 "$app/Contents/MacOS/DeepReader"
cp Info.plist "$app/Contents/Info.plist"
iconset="$stage/DeepReader.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$root/assets/DeepReader-green.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$root/assets/DeepReader-green.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/DeepReader.icns"
rm -rf "$iconset"
python3 "$root/tools/public_release.py" --source-zip
cp "$root/DeepReader-v1.2.0-source.zip" "$out/DeepReader-v1.2.0-macos-source.zip"
cp "$out/DeepReader-v1.2.0-macos-source.zip" "$app/Contents/Resources/Source.zip"
cp "$root/LICENSE-AGPL-3.0.txt" "$app/Contents/Resources/LICENSE.txt"
cp "$root/THIRD-PARTY-NOTICES.md" "$app/Contents/Resources/THIRD-PARTY-NOTICES.md"
cp "$root/macos/README.md" "$app/Contents/Resources/README.md"
printf '%s\n' "$(git -C "$root" rev-parse HEAD)" > "$app/Contents/Resources/SOURCE-COMMIT.txt"
codesign --force --sign - "$app"
codesign --verify --deep --strict --verbose=2 "$app"
lipo -verify_arch arm64 x86_64 "$app/Contents/MacOS/DeepReader"
lipo -info "$app/Contents/MacOS/DeepReader"
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/DeepReader-v1.2.0-macos-universal.zip"
ln -s /Applications "$stage/Applications"
cp "$root/macos/README.md" "$stage/README.md"
cp "$root/LICENSE-AGPL-3.0.txt" "$stage/LICENSE.txt"
hdiutil create -volname DeepReader -srcfolder "$stage" -ov -format UDZO "$out/DeepReader-v1.2.0-macos-universal.dmg"
mkdir -p "$out/smoke"
"$app/Contents/MacOS/DeepReader" --smoke-test "$out/smoke"
(cd "$out" && shasum -a 256 ./*.zip ./*.dmg > SHA256SUMS.txt)
