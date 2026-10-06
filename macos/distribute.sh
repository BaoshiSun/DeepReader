#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Developer ID distribution only. This does not produce a Mac App Store build.
set -euo pipefail
usage() {
    cat <<'EOF'
Usage: bash macos/distribute.sh --app PATH --identity 'Developer ID Application: Name (TEAMID)' --output NEW_DIRECTORY [--notarize --profile KEYCHAIN_PROFILE]

Copies and signs an existing DeepReader.app, then creates a universal ZIP and DMG.
Default: local signing only, no upload. --notarize uploads the signed DMG to Apple,
waits for acceptance, staples the app and DMG, and recreates the ZIP with its ticket.
Credentials must already be stored by `xcrun notarytool store-credentials`.
The input app and existing output directories are never overwritten.
EOF
}
die() { echo "ERROR: $*" >&2; exit 1; }
app="" identity="" out="" profile="" notarize=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app|--identity|--output|--profile)
            [[ $# -ge 2 && -n "$2" ]] || die "Missing value for $1"
            case "$1" in
                --app) app="$2";; --identity) identity="$2";;
                --output) out="$2";; --profile) profile="$2";;
            esac
            shift 2;;
        --notarize) notarize=true; shift;;
        --help|-h) usage; exit 0;;
        *) die "Unknown option: $1";;
    esac
done
[[ -n "$app" && -n "$identity" && -n "$out" ]] || { usage; exit 1; }
[[ "$identity" == "Developer ID Application: "* ]] || die "Use a Developer ID Application identity, not ad-hoc or App Store signing."
[[ "$notarize" == false || -n "$profile" ]] || die "--notarize requires --profile."
[[ ! -e "$out" && ! -L "$out" ]] || die "Output already exists; choose a new directory."
[[ -d "$app/Contents/MacOS" && ! -L "$app" ]] || die "Input must be a real .app directory."
[[ -f "$app/Contents/Resources/Source.zip" && -f "$app/Contents/Resources/SOURCE-COMMIT.txt" ]] || die "Input must include corresponding source and commit metadata."
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")
[[ "$bundle" == org.deepreader.macos && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Unexpected bundle identifier or version."
for tool in codesign security ditto lipo hdiutil shasum python3; do
    command -v "$tool" >/dev/null || die "Missing tool: $tool"
done
python3 - "$app" "$out" <<'PY'
import sys
from pathlib import Path
source, destination = (Path(value).resolve() for value in sys.argv[1:])
if destination == source or source in destination.parents:
    raise SystemExit('Output must not be inside the input app.')
PY
if [[ "$notarize" == true ]]; then
    xcrun --find notarytool >/dev/null
    xcrun --find stapler >/dev/null
fi
security find-identity -v -p codesigning | grep -F -- "\"$identity\"" >/dev/null || die "Signing identity with private key was not found in Keychain."
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/DeepReader" -verify_arch arm64 x86_64
mkdir -p "$out"
out=$(cd "$out" && pwd)
stage="$out/staging"
mkdir "$stage"
signed="$stage/DeepReader.app"
ditto "$app" "$signed"
codesign --force --options runtime --timestamp --sign "$identity" "$signed"
codesign --verify --deep --strict "$signed"
codesign -d --verbose=4 "$signed" 2> "$out/signature.txt"
grep -q 'runtime' "$out/signature.txt" || die "Hardened Runtime was not enabled."
cp "$signed/Contents/Resources/Source.zip" "$out/DeepReader-v${version}-macos-source.zip"
cp "$signed/Contents/Resources/SOURCE-COMMIT.txt" "$out/SOURCE-COMMIT.txt"
ln -s /Applications "$stage/Applications"
cp "$signed/Contents/Resources/README.md" "$stage/README.md"
dmg="$out/DeepReader-v${version}-macos-universal.dmg"
zip="$out/DeepReader-v${version}-macos-universal.zip"
hdiutil create -volname DeepReader -srcfolder "$stage" -format UDZO "$dmg"
codesign --sign "$identity" --timestamp "$dmg"
codesign --verify --strict "$dmg"
if [[ "$notarize" == true ]]; then
    echo 'Uploading the signed DMG to Apple; no API keys are included.'
    # Preserve submission ID/status even on failure. Never equate exit code with acceptance.
    if ! xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait --output-format json > "$out/notarization.json"; then
        die "Submission did not finish successfully. Inspect notarization.json and query its ID before submitting again."
    fi
    python3 - "$out/notarization.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    result = json.load(f)
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization was not Accepted; no files will be marked ready.')
PY
    xcrun stapler staple "$signed"
    xcrun stapler validate "$signed"
    xcrun stapler staple "$dmg"
    xcrun stapler validate "$dmg"
    codesign --verify --deep --strict "$signed"
    spctl --assess --type execute --verbose=2 "$signed"
fi
ditto -c -k --sequesterRsrc --keepParent "$signed" "$zip"
hdiutil verify "$dmg"
(cd "$out" && shasum -a 256 ./*.zip ./*.dmg > SHA256SUMS.txt)
if [[ "$notarize" == true ]]; then
    echo 'Accepted by Apple; app and DMG tickets validated. ZIP includes the stapled app.' > "$out/RESULT.txt"
else
    echo 'Developer ID signed only. NOT notarized. Do not describe this output as notarized.' > "$out/RESULT.txt"
fi
cat "$out/RESULT.txt"
echo "Output: $out"
