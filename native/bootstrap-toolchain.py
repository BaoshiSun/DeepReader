"""Fetch Microsoft's portable build components into this workspace only.

No installer, registry changes, or system PATH changes. VS payloads are verified
against the SHA-256 values in Microsoft's HTTPS channel manifest.
"""
from pathlib import Path
import concurrent.futures
import hashlib
import json
import shutil
import urllib.request
import urllib.parse
import zipfile

ROOT = Path(__file__).resolve().parents[1] / 'build/native/toolchain'
ROOT.mkdir(parents=True, exist_ok=True)
CACHE = ROOT / 'downloads'
CACHE.mkdir(exist_ok=True)

def fetch(url, path, sha256=None):
    if not path.exists():
        tmp = path.with_suffix(path.suffix + '.part')
        urllib.request.urlretrieve(url, tmp)
        tmp.replace(path)
    if sha256 and hashlib.sha256(path.read_bytes()).hexdigest().lower() != sha256.lower():
        raise RuntimeError('Checksum mismatch: ' + path.name)
    return path

def extract(path, dest, prefix=''):
    with zipfile.ZipFile(path) as z:
        for info in z.infolist():
            name = urllib.parse.unquote(info.filename).replace('\\', '/')
            if not name.startswith(prefix) or info.is_dir():
                continue
            target = (dest / name[len(prefix):]).resolve()
            if dest.resolve() not in target.parents:
                raise RuntimeError('Unsafe archive member')
            target.parent.mkdir(parents=True, exist_ok=True)
            with z.open(info) as src, target.open('wb') as out:
                shutil.copyfileobj(src, out)

manifest_path = ROOT / 'vs-manifest.json'
lock_path = Path(__file__).with_name('toolchain-lock.json')
lock = json.loads(lock_path.read_text(encoding='utf-8')) if lock_path.exists() else {}
if not lock and not manifest_path.exists():
    channel = json.load(urllib.request.urlopen('https://aka.ms/vs/17/release/channel'))
    item = next(x for x in channel['channelItems'] if x['id'] == 'Microsoft.VisualStudio.Manifests.VisualStudio')
    fetch(item['payloads'][0]['url'], manifest_path)
manifest = {'packages': lock['vs']} if lock else json.loads(manifest_path.read_text(encoding='utf-8'))
ids = [
    'Microsoft.VC.14.44.17.14.Tools.HostX64.TargetX64.base',
    'Microsoft.VC.14.44.17.14.Tools.HostX64.TargetX64.Res.base',
    'Microsoft.VC.14.44.17.14.CRT.Headers.base',
    'Microsoft.VC.14.44.17.14.CRT.x64.Desktop.base',
    'Microsoft.VC.14.44.17.14.CRT.x64.Store.base',
    'Microsoft.VC.14.44.17.14.CRT.Redist.X64',
    'Microsoft.VC.14.44.17.14.CRT.Redist.X64.base',
    'Microsoft.VC.14.44.17.14.ATL.Headers.base',
    'Microsoft.VC.14.44.17.14.ATL.X64.base',
    'Microsoft.VC.14.44.17.14.Tools.Core.Props',
    'Microsoft.VC.14.44.17.14.Tools.Core.x86',
    'Microsoft.VisualStudio.VC.MSBuild.v170.Base',
    'Microsoft.VisualStudio.VC.MSBuild.v170.Base.Resources',
    'Microsoft.VisualStudio.VC.MSBuild.v170.X64',
    'Microsoft.VisualStudio.VC.MSBuild.v170.X64.v143',
    'Microsoft.VisualStudio.VC.MSBuild.v170.X86',
    'Microsoft.VisualStudio.VC.MSBuild.v170.x86.v143',
    'Microsoft.Build.Dependencies',
]

def vs_package(package_id):
    pkg = next(p for p in manifest['packages'] if p['id'] == package_id and p.get('language') in (None, 'en-US'))
    for part in pkg['payloads']:
        archive = fetch(part['url'], CACHE / (package_id + '.vsix'), part['sha256'])
        extract(archive, ROOT / 'vs', 'Contents/')
    print('Ready:', package_id, flush=True)

def nuget(package, version, dest):
    url = f'https://api.nuget.org/v3-flatcontainer/{package}/{version}/{package}.{version}.nupkg'
    name = f'{package}.{version}.nupkg'
    archive = fetch(url, CACHE / name, lock.get('nuget', {}).get(name))
    extract(archive, dest)
    print('Ready:', package, version, flush=True)

if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        jobs = [pool.submit(vs_package, p) for p in ids]
        jobs += [pool.submit(nuget, p, '10.0.26100.1', ROOT / 'sdk') for p in (
            'microsoft.windows.sdk.cpp', 'microsoft.windows.sdk.cpp.x64')]
        for job in jobs:
            job.result()
    redist = next((ROOT / 'vs/VC/Redist/MSVC').iterdir()).name
    (ROOT / 'vs/VC/Auxiliary/Build/Microsoft.VCRedistVersion.v143.default.props').write_text(
        '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"><PropertyGroup>'
        '<VCRedistVersion>' + redist + '</VCRedistVersion></PropertyGroup></Project>', encoding='utf-8')
