# SPDX-License-Identifier: AGPL-3.0-or-later
"""Offline packaging control-flow tests; no certificate use or Apple requests."""
import copy
import importlib.util
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release_preflight', ROOT / 'macos/release_preflight.py')
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)


class ListingTests(unittest.TestCase):
    def test_localized_fields_fit_store_limits(self):
        data = json.loads((ROOT / 'docs/app-store/listing.json').read_text())
        self.assertEqual(preflight.listing_checks(data), [])
        self.assertIsNone(data['privacy_policy_url'])

    def test_rejects_overlong_text_and_multibyte_keywords(self):
        data = json.loads((ROOT / 'docs/app-store/listing.json').read_text())
        data = copy.deepcopy(data)
        data['localizations']['en-US']['subtitle'] = 'x' * 31
        data['localizations']['zh-Hans']['keywords'] = '词' * 34
        errors = preflight.listing_checks(data)
        self.assertEqual(len(errors), 2)


MOCK_TOOL = r'''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['TEST_TRACE'], 'a') as f:
    f.write(json.dumps([name] + args) + '\n')
if name == 'security':
    if os.environ.get('TEST_NO_IDENTITY') != '1':
        print('  1) TEST "Developer ID Application: Test Only (TESTTEAM01)"')
elif name == 'codesign':
    if '-d' in args:
        print('flags=0x10000(runtime)', file=sys.stderr)
elif name == 'hdiutil' and args[0] == 'create':
    Path(args[-1]).write_bytes(b'OFFLINE TEST DMG PLACEHOLDER')
elif name == 'xcrun':
    if args[0] == '--find':
        print('/offline-test/' + args[1])
    elif args[:2] == ['notarytool', 'submit']:
        print(json.dumps({'id': 'offline-test-id', 'status': os.environ.get('TEST_NOTARY_STATUS', 'Accepted')}))
        sys.exit(int(os.environ.get('TEST_NOTARY_EXIT', '0')))
    elif args[:2] == ['stapler', 'staple']:
        p = Path(args[2])
        if p.is_dir():
            (p / 'Contents/offline-ticket').write_text('test-only ticket')
        else:
            with p.open('ab') as f:
                f.write(b'test-only ticket')
'''


@unittest.skipUnless(sys.platform == 'darwin', 'Packaging control-flow tests use macOS PlistBuddy/ditto')
class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='DeepReader distribution test ')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'Input app/DeepReader.app'
        resources = self.app / 'Contents/Resources'
        resources.mkdir(parents=True)
        (self.app / 'Contents/MacOS').mkdir()
        (self.app / 'Contents/MacOS/DeepReader').write_text('offline fixture')
        with (self.app / 'Contents/Info.plist').open('wb') as f:
            plistlib.dump({'CFBundleIdentifier': 'org.deepreader.macos', 'CFBundleShortVersionString': '1.2.1'}, f)
        for name in ['Source.zip', 'SOURCE-COMMIT.txt', 'README.md']:
            (resources / name).write_text('offline fixture')
        self.bin = self.root / 'mock-bin'
        self.bin.mkdir()
        # Every signing/network-capable tool used by the script is replaced.
        for tool in ['codesign', 'security', 'lipo', 'hdiutil', 'xcrun', 'spctl']:
            p = self.bin / tool
            p.write_text(MOCK_TOOL)
            p.chmod(0o755)
        self.trace = self.root / 'trace.jsonl'
        self.out = self.root / 'new output'
        self.env = {**os.environ, 'PATH': str(self.bin) + os.pathsep + os.environ['PATH'], 'TEST_TRACE': str(self.trace)}

    def invoke(self, notarize=False, **environment):
        args = ['bash', str(ROOT / 'macos/distribute.sh'), '--app', str(self.app),
                '--identity', 'Developer ID Application: Test Only (TESTTEAM01)', '--output', str(self.out)]
        if notarize:
            args += ['--notarize', '--profile', 'offline-test-profile']
        return subprocess.run(args, env={**self.env, **environment}, text=True, capture_output=True, timeout=30)

    def calls(self):
        return [json.loads(line) for line in self.trace.read_text().splitlines()] if self.trace.exists() else []

    def test_default_signing_never_uploads_or_claims_notarization(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(c[0] == 'xcrun' for c in self.calls()))
        self.assertIn('NOT notarized', (self.out / 'RESULT.txt').read_text())
        self.assertFalse((self.app / 'Contents/offline-ticket').exists())
        self.assertEqual((self.app / 'Contents/MacOS/DeepReader').read_text(), 'offline fixture')

    def test_no_certificate_stops_before_creating_output(self):
        result = self.invoke(TEST_NO_IDENTITY='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.out.exists())
        self.assertFalse(any(c[0] == 'codesign' for c in self.calls()))

    def test_existing_output_is_preserved(self):
        self.out.mkdir()
        marker = self.out / 'keep.txt'
        marker.write_text('preserve')
        self.assertNotEqual(self.invoke().returncode, 0)
        self.assertEqual(marker.read_text(), 'preserve')
        self.assertEqual(self.calls(), [])

    def test_output_inside_source_is_rejected_without_modifying_input(self):
        self.out = self.app / 'Contents/new-output'
        self.assertNotEqual(self.invoke().returncode, 0)
        self.assertFalse(self.out.exists())
        self.assertEqual(self.calls(), [])

    def test_rejected_notarization_never_staples_or_emits_ready_result(self):
        result = self.invoke(notarize=True, TEST_NOTARY_STATUS='Invalid')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[:3] == ['xcrun', 'stapler', 'staple'] for c in self.calls()))
        self.assertFalse((self.out / 'RESULT.txt').exists())
        self.assertEqual(json.loads((self.out / 'notarization.json').read_text())['status'], 'Invalid')

    def test_transport_failure_preserves_request_without_retry(self):
        result = self.invoke(notarize=True, TEST_NOTARY_STATUS='In Progress', TEST_NOTARY_EXIT='1')
        self.assertNotEqual(result.returncode, 0)
        calls = self.calls()
        self.assertEqual(sum(c[:3] == ['xcrun', 'notarytool', 'submit'] for c in calls), 1)
        self.assertFalse(any(c[:2] == ['xcrun', 'stapler'] for c in calls))
        self.assertFalse((self.out / 'RESULT.txt').exists())

    def test_accepted_request_staples_both_and_zips_stapled_app(self):
        result = self.invoke(notarize=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls()
        self.assertEqual(sum(c[:3] == ['xcrun', 'stapler', 'staple'] for c in calls), 2)
        self.assertEqual(sum(c[:3] == ['xcrun', 'stapler', 'validate'] for c in calls), 2)
        with zipfile.ZipFile(self.out / 'DeepReader-v1.2.1-macos-universal.zip') as z:
            self.assertIn('DeepReader.app/Contents/offline-ticket', z.namelist())
        verify = subprocess.run(['shasum', '-a', '256', '-c', 'SHA256SUMS.txt'], cwd=self.out, capture_output=True)
        self.assertEqual(verify.returncode, 0)
        self.assertFalse((self.app / 'Contents/offline-ticket').exists())


if __name__ == '__main__':
    unittest.main()
