"""Restore the pinned, fully vendored upstream source and its WebView2 SDK."""
from pathlib import Path
import hashlib
import json
import shutil
import urllib.request
import zipfile

root = Path(__file__).resolve().parents[1]
build = root / 'build/native'
build.mkdir(parents=True, exist_ok=True)
lock = json.loads(Path(__file__).with_name('source-lock.json').read_text(encoding='utf-8'))
archive = build / 'sumatrapdf-3.6.1rel.zip'
bundled = root / 'upstream' / archive.name
if not archive.exists():
    if bundled.exists():
        shutil.copy2(bundled, archive)
    else:
        urllib.request.urlretrieve(lock['source_url'], archive)
if hashlib.sha256(archive.read_bytes()).hexdigest() != lock['source_sha256']:
    raise RuntimeError('Source archive checksum mismatch')
source = build / 'sumatrapdf-3.6.1rel'
if not source.exists():
    with zipfile.ZipFile(archive) as z:
        for member in z.infolist():
            target = (build / member.filename).resolve()
            if build.resolve() not in target.parents:
                raise RuntimeError('Unsafe source archive member')
        z.extractall(build)
webview = build / 'toolchain/downloads/webview2.nupkg'
webview.parent.mkdir(parents=True, exist_ok=True)
if not webview.exists():
    urllib.request.urlretrieve(lock['webview_url'], webview)
if hashlib.sha256(webview.read_bytes()).hexdigest() != lock['webview_sha256']:
    raise RuntimeError('WebView2 SDK checksum mismatch')
with zipfile.ZipFile(webview) as z:
    target = source / 'packages/Microsoft.Web.WebView2.1.0.992.28'
    for member in z.infolist():
        if target.resolve() not in (target / member.filename).resolve().parents:
            raise RuntimeError('Unsafe SDK archive member')
    z.extractall(target)
print('Pinned source and WebView2 SDK are ready')
