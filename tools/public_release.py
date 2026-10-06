"""Build/audit an explicit public source set. Never print credential values."""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = "1.2.0"
PRODUCT = "DeepReader"
PUBLIC_PATHS = tuple("""
.gitignore
.github/workflows/release-checks.yml
.github/workflows/macos-build.yml
macos/Package.swift
macos/Info.plist
macos/build.sh
macos/README.md
macos/Sources/DeepReaderCore/Models.swift
macos/Sources/DeepReaderCore/LibraryStore.swift
macos/Sources/DeepReaderCore/Credentials.swift
macos/Sources/DeepReaderCore/AIClient.swift
macos/Sources/DeepReaderDesktop/PDFReader.swift
macos/Sources/DeepReaderDesktop/ReaderModel.swift
macos/Sources/DeepReaderDesktop/Sidebar.swift
macos/Sources/DeepReaderDesktop/ReaderWindow.swift
macos/Sources/DeepReaderDesktop/Application.swift
macos/Sources/DeepReaderDesktop/SmokeTest.swift
macos/Sources/DeepReader/DeepReader.swift
macos/Tests/DeepReaderTests/CoreTests.swift
macos/Tests/DeepReaderTests/PDFTests.swift
macos/Tests/DeepReaderTests/AITests.swift
README.md
LICENSE
LICENSE-AGPL-3.0.txt
THIRD-PARTY-NOTICES.md
SECURITY.md
CONTRIBUTING.md
DeepSeekReader.exe.config
bootstrap-build.py
build.ps1
requirements-build.txt
docs/legacy-helper.md
docs/RELEASING.md
docs/LICENSE-REVIEW.md
docs/MODIFICATIONS.md
native/README.md
native/DeepSeekCore.h
native/DeepSeekCore.cpp
native/DeepSeekPanel.h
native/DeepSeekPanel.cpp
native/ReadingLibrary.h
native/ReadingLibrary.cpp
native/BookLibrary.h
native/BookLibrary.cpp
native/ReaderHighlights.h
native/ReaderHighlights.cpp
assets/DeepReader-green.png
assets/DeepReader.ico
native/NativeCoreTests.cpp
native/NativeIntegration.cs
native/apply-native.py
native/build-native.ps1
native/test-core.ps1
native/test-native.ps1
native/package-native.py
native/prepare-source.py
native/bootstrap-toolchain.py
native/prepare-msbuild.py
native/source-lock.json
native/toolchain-lock.json
src/Core.cs
src/Integration.cs
src/Program.cs
src/Selection.cs
src/SelfTests.cs
src/UI.cs
src/context_worker.py
tests/SelectionIntegration.cs
tests/make_smoke_pdf.py
tests/verify_native_annotations.py
tests/test-selection.ps1
tests/test_context.py
tests/test_packaged.py
tests/test_release.py
tools/public_release.py
""".split())
BINARY_ASSETS = {"assets/DeepReader-green.png": b"\x89PNG\r\n\x1a\n", "assets/DeepReader.ico": b"\x00\x00\x01\x00"}

PRIVATE_NAMES = {"aireader.json", "deepseek.json", "config.json", "sumatrapdf-settings.txt"}
SECRET_FIELDS = {"apikey", "protectedkey", "accesstoken", "secretkey"}
PATTERNS = (
    ("API credential", re.compile(rb"\bsk-(?:or-v1-|proj-|ant-api\d+-)?[A-Za-z0-9_-]{20,}\b")),
    ("Google API credential", re.compile(rb"\bAIza[A-Za-z0-9_-]{30,}\b")),
    ("GitHub credential", re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})\b")),
    ("DPAPI ciphertext", re.compile(rb"AQAAANCMnd8BFdERjHoAwE/Cl\+s[A-Za-z0-9+/=]{40,}")),
    ("private key", re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("personal Windows path", re.compile(rb"[A-Za-z]:[\\/]+Users[\\/]+[^\\/\s\"<>]+", re.I)),
)


def credential_fields(value, trail=()):
    """Return field names only; encrypted values are private too."""
    found = []
    if isinstance(value, dict):
        for key, item in value.items():
            normalized = re.sub(r"[_-]", "", key).lower()
            secret = normalized in SECRET_FIELDS or (trail and trail[-1].lower() == "keys")
            if secret and isinstance(item, str) and item:
                found.append("/".join(trail + (key,)))
            elif isinstance(item, (dict, list)):
                found.extend(credential_fields(item, trail + (key,)))
    elif isinstance(value, list):
        for i, item in enumerate(value):
            found.extend(credential_fields(item, trail + (str(i),)))
    return found


def inspect_bytes(name, data):
    problems = [label for label, pattern in PATTERNS if pattern.search(data)]
    try:
        value = json.loads(data.decode("utf-8-sig"))
    except (ValueError, UnicodeError):
        value = None
    if credential_fields(value):
        problems.append("nonempty credential field")
    if problems:
        raise ValueError(f"Refusing to publish {name}: {', '.join(problems)}")


def safe_name(name):
    path = PurePosixPath(name)
    if "\\" in name or path.is_absolute() or ".." in path.parts or ":" in name:
        raise ValueError("Unsafe archive path")
    if any(p.lower() in {"aihistory", "booklibrary", ".git", ".env"} for p in path.parts):
        raise ValueError(f"Private directory in archive: {name}")
    if path.name.lower() in PRIVATE_NAMES or path.suffix.lower() in {".lnk", ".log", ".tmp", ".pem", ".key"}:
        raise ValueError(f"Private file in archive: {name}")
    if path.name.startswith(".env.") or ".backup-" in path.name:
        raise ValueError(f"Private file in archive: {name}")


def source_files(root=ROOT):
    root = root.resolve()
    result = []
    for name in PUBLIC_PATHS:
        safe_name(name)
        path = root / name
        if not path.is_file() or not path.resolve().is_relative_to(root) or path.is_symlink():
            raise ValueError(f"Missing or unsafe public source: {name}")
        data = path.read_bytes()
        if name in BINARY_ASSETS:
            if not data.startswith(BINARY_ASSETS[name]):
                raise ValueError(f"Invalid public image: {name}")
        else:
            data.decode("utf-8-sig")
        inspect_bytes(name, data)
        result.append((name, data))
    return result


def check_tracked(root=ROOT):
    """CI must reject extra committed files outside the reviewed public manifest."""
    output = subprocess.run(["git", "ls-files", "-z"], cwd=root, check=True, capture_output=True).stdout
    tracked = {name.decode("utf-8") for name in output.split(b"\0") if name}
    extra = tracked - set(PUBLIC_PATHS)
    missing = set(PUBLIC_PATHS) - tracked
    if extra or missing:
        raise ValueError(f"Git file list differs from public manifest: {len(extra)} extra, {len(missing)} missing")


def audit_zip(path, expected_names=None, defaults=None):
    """Check every entry; only an exact clean reader-settings payload is allowed."""
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(set(names)) != len(names):
            raise ValueError("Duplicate archive entry")
        if expected_names is not None and set(names) != set(expected_names):
            raise ValueError("Archive differs from the public file manifest")
        if archive.testzip() is not None:
            raise ValueError("Archive CRC check failed")
        for member in archive.infolist():
            name = member.filename
            data = archive.read(member)
            if name == f"{PRODUCT}/SumatraPDF-settings.txt" and defaults is not None:
                if data != defaults:
                    raise ValueError("Reader settings contain non-default data")
            else:
                safe_name(name)
            # The official corresponding-source archive is hash pinned separately.
            if name.endswith("source/upstream/sumatrapdf-3.6.1rel.zip"):
                lock = json.loads((ROOT / "native/source-lock.json").read_text(encoding="utf-8"))
                if hashlib.sha256(data).hexdigest() != lock["source_sha256"]:
                    raise ValueError("Upstream source checksum mismatch")
            else:
                inspect_bytes(name, data)
    return len(names)


def make_source_zip(root=ROOT):
    files = source_files(root)
    manifest = "".join(hashlib.sha256(data).hexdigest() + "  " + name + "\n" for name, data in files)
    files.append(("SOURCE-MANIFEST.sha256", manifest.encode("utf-8")))
    target = root / f"{PRODUCT}-v{VERSION}-source.zip"
    prefix = f"{PRODUCT}-source/"
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in files:
            archive.writestr(prefix + name, data)
    audit_zip(target, [prefix + name for name, _ in files])
    return target


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-zip", action="store_true", help="create the audited source archive")
    parser.add_argument("--check-tracked", action="store_true", help="require Git to contain only the public manifest")
    args = parser.parse_args()
    files = source_files()
    print(f"PASS: {len(files)} public source files; no detected credential values or personal paths")
    if args.check_tracked:
        check_tracked()
        print("PASS: Git contains exactly the public source manifest")
    if args.source_zip:
        target = make_source_zip()
        print(f"Created {target.name} ({target.stat().st_size} bytes)")
