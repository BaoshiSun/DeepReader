"""Assemble the official .NET Framework MSBuild NuGet runtime locally."""
from pathlib import Path
import re
import shutil
import xml.etree.ElementTree as ET
from importlib import util

spec = util.spec_from_file_location('bootstrap', Path(__file__).with_name('bootstrap-toolchain.py'))
b = util.module_from_spec(spec)
spec.loader.exec_module(b)
out = b.ROOT / 'msbuild-bin'
out.mkdir(exist_ok=True)
seen = set()
frameworks = ['net472', 'net471', 'net47', 'net462', 'net461', 'net46', 'net452', 'net45', 'net40', 'netstandard2.0', 'netstandard1.3']

def rank(s):
    s = s.lower().replace('.netframework', 'net').replace('.netstandard', 'netstandard')
    if s.startswith('net') and not s.startswith('netstandard'):
        s = s.replace('.', '')
    return frameworks.index(s) if s in frameworks else 999

def install(name, version):
    name = name.lower()
    version = re.search(r'\d+(?:\.\d+)+(?:-[a-zA-Z0-9.]+)?', version).group(0)
    if (name, version) in seen:
        return
    seen.add((name, version))
    folder = b.ROOT / 'nuget-packages' / (name + '.' + version)
    if not folder.exists():
        b.nuget(name, version, folder)
    ns = {'n': 'http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd'}
    tree = ET.parse(next(folder.glob('*.nuspec')))
    # NuGet nuspec namespace versions vary.
    for el in tree.iter():
        el.tag = el.tag.split('}')[-1]
    deps = tree.find('metadata/dependencies')
    if deps is not None:
        groups = list(deps.findall('group'))
        chosen = min(groups, key=lambda x: rank(x.get('targetFramework', '')), default=deps)
        if chosen is deps or rank(chosen.get('targetFramework', '')) < 999:
            for dep in chosen.findall('dependency'):
                install(dep.get('id'), dep.get('version'))
    lib = folder / 'lib'
    if lib.exists():
        choices = [p for p in lib.iterdir() if p.is_dir() and rank(p.name) < 999]
        if choices:
            for p in min(choices, key=lambda p: rank(p.name)).glob('*'):
                if p.suffix.lower() in ('.dll', '.exe', '.config'):
                    shutil.copy2(p, out / p.name)
    content = folder / 'contentFiles/any/net472'
    if content.exists():
        shutil.copytree(content, out, dirs_exist_ok=True)
    print('MSBuild dependency ready:', name, version, flush=True)

install('Microsoft.Build.Runtime', '17.14.8')
