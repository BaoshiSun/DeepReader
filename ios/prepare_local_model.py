#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Download pinned public local-inference dependencies; verify before extracting."""
from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent
DEST = ROOT / '.build/local-qwen'
MODEL = ('Qwen3-0.6B-Q4_K_M.gguf',
    'https://huggingface.co/lmstudio-community/Qwen3-0.6B-GGUF/resolve/3334d820ab76652cf6e242d7c6302b10f0951f23/Qwen3-0.6B-Q4_K_M.gguf',
    'cd47557a67d7e8f2891d98b5e1dbf2988544569fdf4f1bdb30e92b71aa61b548')
FRAMEWORK = ('llama.zip',
    'https://github.com/ggml-org/llama.cpp/releases/download/b11624/llama-b11624-xcframework.zip',
    'a6dd8a5ce837600544320a198f0550d74902f4fce543a00b4e157540235f03df')

def checksum(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''): digest.update(chunk)
    return digest.hexdigest()

def download(item):
    name, url, expected = item
    path = DEST / name
    if not path.exists() or checksum(path) != expected:
        partial = path.with_suffix(path.suffix + '.partial')
        print(f'Downloading {name}…', flush=True)
        with urllib.request.urlopen(url, timeout=120) as source, partial.open('wb') as output:
            shutil.copyfileobj(source, output)
        if checksum(partial) != expected:
            partial.unlink()
            raise RuntimeError(f'Checksum mismatch: {name}')
        partial.replace(path)
    print(f'Verified {name}', flush=True)
    return path

def simulator_framework():
    source = DEST / 'llama-source'
    commit = 'af0579c78a07a555d84830d01da7b61cfadbc7ef'
    if not source.exists():
        subprocess.run(['git', 'clone', '--depth', '1', '--branch', 'b11624',
                        'https://github.com/ggml-org/llama.cpp.git', str(source)], check=True)
    actual = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != commit: raise RuntimeError('Unexpected llama.cpp source revision')
    sim = source / 'build-apple/llama.xcframework/ios-arm64_x86_64-simulator/llama.framework'
    if not sim.exists():
        env = os.environ.copy()
        if not shutil.which('cmake'):
            build_tools = DEST / 'build-tools'
            subprocess.run([sys.executable, '-m', 'venv', str(build_tools)], check=True)
            subprocess.run([str(build_tools / 'bin/pip'), 'install', 'cmake==4.4.4'], check=True)
            env['PATH'] = str(build_tools / 'bin') + os.pathsep + env.get('PATH', '')
        subprocess.run(['bash', 'build-xcframework.sh', 'ios-sim'], cwd=source, env=env, check=True)
    combined = DEST / 'llama-combined.xcframework'
    if combined.exists(): shutil.rmtree(combined)
    subprocess.run(['xcodebuild', '-create-xcframework',
        '-framework', str(DEST / 'build-apple/llama.xcframework/ios-arm64/llama.framework'),
        '-framework', str(sim), '-output', str(combined)], check=True)

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    download(MODEL)
    archive = download(FRAMEWORK)
    with zipfile.ZipFile(archive) as z:
        for item in z.infolist():
            if not (DEST / item.filename).resolve().is_relative_to(DEST.resolve()):
                raise RuntimeError('Unsafe archive path')
    subprocess.run(['ditto', '-x', '-k', str(archive), str(DEST)], check=True)
    if '--simulator' in sys.argv: simulator_framework()
    subprocess.run([sys.executable, str(ROOT / 'prepare_project.py'), '--local-qwen'], check=True)

if __name__ == '__main__': main()
