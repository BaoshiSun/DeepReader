"""Package only the audited public manifest; never import user credentials."""
from pathlib import Path
import hashlib
import shutil
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'tools'))
from public_release import PRODUCT, VERSION, audit_zip, inspect_bytes, source_files

public_source = source_files(root)
upstream = root / 'build/native/sumatrapdf-3.6.1rel'
out = root / 'dist' / PRODUCT
out.mkdir(parents=True, exist_ok=True)
exe_name = PRODUCT + '.exe'
shutil.copy2(upstream / 'out/rel64/SumatraPDF.exe', out / exe_name)
defaults = 'UiLanguage = cn\nCheckForUpdates = false\nReuseInstance = true\nShowToc = false\n'
settings = out / 'SumatraPDF-settings.txt'
if not settings.exists():
    settings.write_text(defaults, encoding='utf-8')
# Credentials are user data. Never import them when building a distribution.
shutil.copy2(root / 'native/README.md', out / '使用说明.md')
shutil.copy2(root / 'LICENSE-AGPL-3.0.txt', out / 'LICENSE-AGPL-3.0.txt')
shutil.copy2(upstream / 'COPYING', out / 'LICENSE-GPL-3.0.txt')
shutil.copy2(upstream / 'COPYING.BSD', out / 'COPYING.BSD')
shutil.copy2(upstream / 'AUTHORS', out / 'SumatraPDF-AUTHORS.txt')
webview_license = upstream / 'packages/Microsoft.Web.WebView2.1.0.992.28/LICENSE.txt'
if webview_license.exists():
    shutil.copy2(webview_license, out / 'WebView2-LICENSE.txt')
shutil.copy2(root / 'THIRD-PARTY-NOTICES.md', out / 'THIRD-PARTY-NOTICES.txt')
shutil.copy2(root / 'docs/MODIFICATIONS.md', out / 'MODIFICATIONS.txt')
shutil.copy2(root / 'docs/LICENSE-REVIEW.md', out / 'LICENSE-REVIEW.md')
source = out / 'source'
for name, data in public_source:
    dest = source / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
(source / 'upstream').mkdir(parents=True, exist_ok=True)
shutil.copy2(root / 'build/native/sumatrapdf-3.6.1rel.zip', source / 'upstream/sumatrapdf-3.6.1rel.zip')
digest = hashlib.sha256((out / exe_name).read_bytes()).hexdigest()
(out / 'SHA256SUMS.txt').write_text(digest + '  ' + exe_name + '\n', encoding='ascii')
archive = root / f'{PRODUCT}-v{VERSION}-win64.zip'
public_files = {exe_name, 'SumatraPDF-settings.txt', '使用说明.md',
                'LICENSE-AGPL-3.0.txt', 'LICENSE-GPL-3.0.txt', 'COPYING.BSD',
                'SumatraPDF-AUTHORS.txt', 'WebView2-LICENSE.txt',
                'THIRD-PARTY-NOTICES.txt', 'SHA256SUMS.txt', 'MODIFICATIONS.txt', 'LICENSE-REVIEW.md'}
entries = []
for name in sorted(public_files):
    data = defaults.encode('utf-8') if name == 'SumatraPDF-settings.txt' else (out / name).read_bytes()
    inspect_bytes(name, data)
    entries.append((PRODUCT + '/' + name, data))
entries += [(PRODUCT + '/source/' + name, data) for name, data in public_source]
upstream_name = 'source/upstream/sumatrapdf-3.6.1rel.zip'
entries.append((PRODUCT + '/' + upstream_name, (out / upstream_name).read_bytes()))
temporary = archive.with_suffix('.zip.tmp')
with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name, data in entries:
        z.writestr(name, data)
audit_zip(temporary, [name for name, _ in entries], defaults.encode('utf-8'))
temporary.replace(archive)
print('Native executable:', (out / exe_name).stat().st_size, 'bytes')
print('Portable package with corresponding source:', archive.stat().st_size, 'bytes')
print('No credentials imported; release package excludes credentials and reading history')
