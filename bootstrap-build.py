"""Download pinned official PyPI wheels into a project-local build runtime."""
import hashlib
import json
import shutil
import sys
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PACKAGES = {
    "PyMuPDF": "1.28.2", "pyinstaller": "6.22.3", "altgraph": "0.17.5",
    "packaging": "26.3", "pefile": "2024.8.26",
    "pyinstaller-hooks-contrib": "2026.8", "pywin32-ctypes": "0.2.3",
    "setuptools": "84.0.0",
}


def main():
    if sys.platform != "win32" or sys.maxsize <= 2**32:
        raise SystemExit("Build requires 64-bit Windows Python.")
    packages = ROOT / "build" / "packages"
    wheels = ROOT / "build" / "wheels"
    packages.mkdir(parents=True, exist_ok=True)
    wheels.mkdir(parents=True, exist_ok=True)
    for name, version in PACKAGES.items():
        url = f"https://pypi.org/pypi/{name}/{version}/json"
        with urllib.request.urlopen(url, timeout=30) as response:
            metadata = json.load(response)
        matches = [item for item in metadata["urls"] if item["filename"].endswith(".whl")
                   and ("py3-none-any" in item["filename"]
                        or "py2.py3-none-any" in item["filename"]
                        or "py3-none-win_amd64" in item["filename"]
                        or "cp310-abi3-win_amd64" in item["filename"])]
        if len(matches) != 1:
            raise RuntimeError(f"Cannot select a unique Windows wheel for {name} {version}")
        item = matches[0]
        wheel = wheels / item["filename"]
        expected = item["digests"]["sha256"]
        if not wheel.exists() or hashlib.sha256(wheel.read_bytes()).hexdigest() != expected:
            print(f"Downloading {item['filename']}", flush=True)
            with urllib.request.urlopen(item["url"], timeout=60) as response, wheel.open("wb") as out:
                shutil.copyfileobj(response, out)
        if hashlib.sha256(wheel.read_bytes()).hexdigest() != expected:
            raise RuntimeError(f"SHA-256 mismatch: {wheel.name}")
        with zipfile.ZipFile(wheel) as archive:
            for entry in archive.infolist():
                destination = (packages / entry.filename).resolve()
                if not destination.is_relative_to(packages.resolve()):
                    raise RuntimeError("Unexpected wheel path")
            archive.extractall(packages)
        print(f"Ready: {name} {version}", flush=True)
    print(f"Build runtime: {packages}", flush=True)


if __name__ == "__main__":
    main()
