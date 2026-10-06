"""Credential and packaging regression tests: synthetic strings only, no API calls."""
from pathlib import Path
import importlib.util
import json
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location("public_release", Path(__file__).resolve().parents[1] / "tools/public_release.py")
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def test_ciphertext_and_plaintext_fields_are_private(self):
        for obj in ({"ProtectedKey": "synthetic cipher"}, {"Keys": {"DeepSeek": "cipher"}}, {"api_key": "example"}):
            with self.assertRaisesRegex(ValueError, "nonempty credential field"):
                release.inspect_bytes("example.json", json.dumps(obj).encode())
        release.inspect_bytes("example.json", b'{"Keys":{"DeepSeek":""},"Model":"deepseek-flash"}')

    def test_tokens_in_source_are_detected_without_echoing_them(self):
        for prefix in ("sk-", "sk-or-v1-", "AIza", "ghp_", "github_pat_"):
            token = (prefix + "x" * 48).encode()
            with self.assertRaises(ValueError) as caught:
                release.inspect_bytes("example.txt", b"prefix " + token)
            self.assertNotIn(token.decode(), str(caught.exception))

    def test_dpapi_ciphertext_is_detected_in_arbitrary_files(self):
        cipher = ("AQAAANCMnd8BFdERjHoAwE/Cl+s" + "A" * 64).encode()
        with self.assertRaisesRegex(ValueError, "DPAPI ciphertext"):
            release.inspect_bytes("example.txt", cipher)

    def test_private_data_paths_and_traversal_are_rejected(self):
        for name in ("AIReader.json", "a/DeepSeek.json", "a/config.json", "a/AIHistory/1.json",
                     "a/BookLibrary/1.json", "a/.git/config", "a/.env", "a/.env.local", "a/read.lnk", "a/out.log",
                     "a/config.json.backup-old", "a/../file", "/absolute", "C:/file", "a\\file"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                release.safe_name(name)

    def test_personal_windows_path_is_rejected(self):
        sample = b"C:" + b"\\Users\\" + b"example\\paper.pdf"
        with self.assertRaisesRegex(ValueError, "personal Windows path"):
            release.inspect_bytes("example.md", sample)

    def test_manifest_is_complete_and_clean(self):
        files = release.source_files()
        self.assertEqual(len(files), len(set(release.PUBLIC_PATHS)))
        self.assertIn("tests/make_smoke_pdf.py", dict(files))
        self.assertIn("tools/public_release.py", dict(files))
        self.assertIn("native/ReaderHighlights.cpp", dict(files))
        for name, signature in release.BINARY_ASSETS.items():
            self.assertTrue(dict(files)[name].startswith(signature))

    def test_image_allowlist_does_not_bypass_credential_scan(self):
        name = "assets/DeepReader-green.png"
        with self.assertRaisesRegex(ValueError, "API credential"):
            release.inspect_bytes(name, release.BINARY_ASSETS[name] + b"sk-" + b"x" * 48)

    def test_zip_rejects_unexpected_entries_and_private_reader_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "package.zip"
            name = f"{release.PRODUCT}/SumatraPDF-settings.txt"
            clean = b"UiLanguage = cn\n"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(name, clean)
            self.assertEqual(release.audit_zip(path, [name], clean), 1)
            with self.assertRaises(ValueError):
                release.audit_zip(path, [], clean)
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(name, clean + b"FileStates = private document\n")
            with self.assertRaisesRegex(ValueError, "non-default"):
                release.audit_zip(path, [name], clean)

    def test_zip_rejects_secrets_even_in_allowed_filename(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "source.zip"
            name = f"{release.PRODUCT}-source/notes.json"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr(name, '{"ProtectedKey":"synthetic"}')
            with self.assertRaisesRegex(ValueError, "credential"):
                release.audit_zip(path, [name])


if __name__ == "__main__":
    unittest.main()
