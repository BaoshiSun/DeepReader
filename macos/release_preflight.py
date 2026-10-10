#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Read-only preparation checks. Never reads keys or attempts an Apple login."""
import argparse
import json
import platform
import plistlib
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return None


def listing_checks(data):
    errors = []
    limits = {'name': 30, 'subtitle': 30, 'promotional_text': 170, 'description': 4000}
    for locale, fields in data['localizations'].items():
        for key, limit in limits.items():
            value = fields.get(key, '')
            if not value or len(value) > limit:
                errors.append(f'{locale}.{key}: must contain 1–{limit} characters')
        # Conservative byte check for multibyte keywords.
        if not fields.get('keywords') or len(fields['keywords'].encode('utf-8')) > 100:
            errors.append(f'{locale}.keywords: keep within 100 UTF-8 bytes')
    return errors


def report():
    checks = []
    def add(name, ok, detail):
        checks.append({'name': name, 'status': 'PASS' if ok else 'PENDING', 'detail': detail})
    add('macOS host', platform.system() == 'Darwin', platform.mac_ver()[0] or platform.system())
    for tool in ('git', 'swift', 'python3', 'codesign', 'security', 'ditto', 'lipo', 'hdiutil', 'shasum', 'shellcheck'):
        add(tool, bool(shutil.which(tool)), 'Available' if shutil.which(tool) else 'Not installed')
    for tool in ('notarytool', 'stapler'):
        result = run('xcrun', '--find', tool)
        add(tool, result is not None and result.returncode == 0, 'Apple command-line tool')
    result = run('xcodebuild', '-version')
    add('Full Xcode selected', result is not None and result.returncode == 0,
        result.stdout.strip() if result and result.returncode == 0 else 'Install compatible Xcode, finish first launch, then select its developer directory')
    result = run('xcodebuild', '-checkFirstLaunchStatus')
    add('Xcode first-launch setup', result is not None and result.returncode == 0,
        'License and required components must be completed in Xcode before building/testing')
    result = run('security', 'find-identity', '-v', '-p', 'codesigning')
    identities = result.stdout if result and result.returncode == 0 else ''
    add('Developer ID Application identity', '"Developer ID Application:' in identities,
        'Requires approved membership and a certificate with its private key')
    add('App Store distribution identity', any(x in identities for x in ('"Apple Distribution:', '"3rd Party Mac Developer Application:')),
        'Required later for the separate App Store build')
    with (ROOT / 'macos/Info.plist').open('rb') as f:
        info = plistlib.load(f)
    data = json.loads((ROOT / 'docs/app-store/listing.json').read_text())
    errors = listing_checks(data)
    add('Store copy length checks', not errors, '; '.join(errors) or 'Chinese and English draft fields fit local limits; App Store Connect is authoritative')
    # Explicit uncompleted gates; passing environment checks is not store approval.
    pending = [
        'Owner confirms seller identity, pricing, territories, review contact and public privacy-policy URL',
        'Review AGPL/LGPL distribution terms and static libmobi relinking obligations',
        'Complete signed sandbox PDF/export/cancellation checks and decide profile migration; bookmark/EPUB/archive checks implemented',
        'Approve public privacy policy and in-app link; verify provider terms/retention; per-operation AI consent implemented',
        'Finalize privacy data declarations and App Privacy answers; file-metadata API reasons declared',
        'Sign and validate Xcode App Store archive, provisioning and TestFlight build; unsigned universal archive implemented',
        'Capture final screenshots and supply working private review access; test real provider calls',
    ]
    return {'bundle_id': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'],
            'checks': checks, 'store_ready': False, 'manual_gates': pending}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', action='store_true')
    parser.add_argument('--strict', action='store_true', help='Exit 1 when any environment check is pending; does not certify store readiness')
    args = parser.parse_args()
    result = report()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print(f"DeepReader {result['version']} · {result['bundle_id']}")
        for item in result['checks']:
            print(f"{item['status']}: {item['name']} — {item['detail']}")
        print('NOT READY for App Store submission. Outstanding engineering/review gates:')
        for item in result['manual_gates']:
            print(f'- {item}')
    return int(args.strict and any(item['status'] != 'PASS' for item in result['checks']))


if __name__ == '__main__':
    raise SystemExit(main())
