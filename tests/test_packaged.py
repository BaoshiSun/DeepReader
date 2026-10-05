import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import pymupdf


@unittest.skipUnless(os.environ.get("CONTEXT_WORKER_EXE"), "Requires built executable")
class PackagedTests(unittest.TestCase):
    def run_worker(self, paragraphs, selected):
        with tempfile.TemporaryDirectory() as folder:
            pdf = Path(folder) / "测试 article.pdf"
            with pymupdf.open() as doc:
                for paragraph in paragraphs:
                    page = doc.new_page()
                    if paragraph:
                        page.insert_textbox(pymupdf.Rect(60, 70, 500, 180), paragraph, fontsize=12)
                doc.save(pdf)
            proc = subprocess.run([os.environ["CONTEXT_WORKER_EXE"]],
                                  input=json.dumps({"file": str(pdf), "page": 1, "selected": selected},
                                                   ensure_ascii=False).encode("utf-8"),
                                  capture_output=True, timeout=20, check=True)
            result = json.loads(proc.stdout.decode("utf-8"))
            self.assertTrue(result["ok"], result)
            return result

    def test_portable_worker_repeated_word(self):
        result = self.run_worker(["The river bank was steep, but the bank approved a loan."], "bank")
        self.assertEqual(len(result["candidates"]), 2)
        self.assertIn("river ⟦bank⟧", result["candidates"][0]["text"])

    def test_portable_worker_cross_page(self):
        result = self.run_worker(["A resilient system", "recovers from failure."],
                                 "A resilient system recovers from failure.")
        self.assertTrue(result["candidates"])

    def test_portable_worker_scan_fallback(self):
        result = self.run_worker([""], "bank")
        self.assertEqual(result["candidates"], [])
        self.assertTrue(result["warning"])
