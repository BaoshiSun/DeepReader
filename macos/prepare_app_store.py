#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Prepare reproducible resources for the Xcode app target; does not sign or upload."""
import plistlib
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import public_release


def main():
    output = ROOT / 'macos/.build/app-store-resources'
    output.mkdir(parents=True, exist_ok=True)
    subprocess.run([sys.executable, str(ROOT / 'tools/public_release.py'), '--source-zip'], check=True)
    shutil.copy2(ROOT / f'DeepReader-v{public_release.VERSION}-source.zip', output / 'Source.zip')
    for source, name in [('LICENSE-AGPL-3.0.txt', 'LICENSE.txt'),
                         ('THIRD-PARTY-NOTICES.md', 'THIRD-PARTY-NOTICES.md'),
                         ('macos/README.md', 'README.md')]:
        shutil.copy2(ROOT / source, output / name)
    commit = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = bool(subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain'], text=True).strip())
    (output / 'SOURCE-COMMIT.txt').write_text(commit + (' (working tree changes included)' if dirty else '') + '\n')
    with (ROOT / 'macos/Info.plist').open('rb') as f:
        info = plistlib.load(f)
    info['CFBundleVersion'] = '4'
    info['DeepReaderAppStoreBuild'] = True
    info['CFBundleGetInfoString'] = 'DeepReader for macOS — AGPL-3.0-or-later'
    info['LSApplicationCategoryType'] = 'public.app-category.books'
    info['CFBundleSupportedPlatforms'] = ['MacOSX']
    with (output / 'Info.plist').open('wb') as f:
        plistlib.dump(info, f)
    iconset = output / 'DeepReader.iconset'
    iconset.mkdir(exist_ok=True)
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f'icon_{size}x{size}' + ('@2x' if scale == 2 else '') + '.png'
            subprocess.run(['sips', '-z', str(size * scale), str(size * scale),
                            str(ROOT / 'assets/DeepReader-green.png'), '--out', str(iconset / name)],
                           check=True, stdout=subprocess.DEVNULL)
    subprocess.run(['iconutil', '-c', 'icns', str(iconset), '-o', str(output / 'DeepReader.icns')], check=True)
    print(f'Prepared Xcode resources in {output}. No signing or upload performed.')


if __name__ == '__main__':
    main()
