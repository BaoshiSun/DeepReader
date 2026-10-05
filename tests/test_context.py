import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
import pymupdf
from context_worker import extract_context, occurrences, bounded_context, MAX_CONTEXT


class ContextTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.pdf = Path(self.temp.name) / "含 空格 paper.pdf"

    def tearDown(self):
        self.temp.cleanup()

    def create_pdf(self, pages):
        with pymupdf.open() as doc:
            for paragraphs in pages:
                page = doc.new_page()
                for i, text in enumerate(paragraphs):
                    page.insert_textbox(pymupdf.Rect(60, 70 + i * 160, 500, 180 + i * 160),
                                        text, fontsize=12)
            doc.save(self.pdf)

    def test_current_page_disambiguates_meaning(self):
        self.create_pdf([["The river bank was steep."],
                         ["The bank approved the loan. This is about finance."]])
        result = extract_context(str(self.pdf), 2, "bank")
        self.assertEqual(len(result["candidates"]), 1)
        self.assertIn("loan", result["candidates"][0]["text"])
        self.assertNotIn("river", result["candidates"][0]["text"])

    def test_repeated_word_requires_context_choice(self):
        self.create_pdf([["The river bank was steep.",
                          "The bank approved a loan."]])
        result = extract_context(str(self.pdf), 1, "bank")
        self.assertEqual(len(result["candidates"]), 2)
        self.assertIn("river", result["candidates"][0]["text"])
        self.assertIn("loan", result["candidates"][1]["text"])

    def test_adjacent_visible_page(self):
        self.create_pdf([["Introduction."], ["A resilient system recovers from failure."]])
        result = extract_context(str(self.pdf), 1, "resilient")
        self.assertEqual(result["candidates"][0]["page"], 2)

    def test_cross_page_sentence(self):
        self.create_pdf([["A resilient system"], ["recovers from failure."]])
        result = extract_context(str(self.pdf), 1, "A resilient system recovers from failure.")
        self.assertTrue(result["candidates"])
        self.assertIn("跨页", result["candidates"][0]["label"])

    def test_scanned_pdf_returns_no_fabricated_context(self):
        self.create_pdf([[]])
        result = extract_context(str(self.pdf), 1, "bank")
        self.assertEqual(result["candidates"], [])
        self.assertTrue(result["warning"])

    def test_matching_ligatures_wraps_and_word_boundaries(self):
        self.assertTrue(occurrences("A signiﬁcant improve-\nment.", "significant improvement"))
        self.assertFalse(occurrences("bankruptcy", "bank"))
        self.assertTrue(occurrences("The BANK approved.", "bank"))
        self.assertTrue(occurrences("这是一个上下文相关的含义。", "上下文"))

    def test_long_paragraph_keeps_selected_sentence(self):
        text = "prefix " * 1200 + "selected meaning" + " tail" * 1200
        start = text.index("selected meaning")
        context = bounded_context(text, start, start + len("selected meaning"))
        self.assertIn("⟦selected meaning⟧", context)
        self.assertLessEqual(len(context), MAX_CONTEXT + 4)

    def test_repeated_word_in_one_paragraph_identifies_occurrence(self):
        self.create_pdf([["The river bank was steep, but the bank approved a loan."]])
        result = extract_context(str(self.pdf), 1, "bank")
        self.assertEqual(len(result["candidates"]), 2)
        self.assertIn("river ⟦bank⟧", result["candidates"][0]["text"])
        self.assertIn("the ⟦bank⟧ approved", result["candidates"][1]["text"])

    def test_invalid_page_and_long_selection(self):
        self.create_pdf([["Test."]])
        with self.assertRaises(ValueError):
            extract_context(str(self.pdf), 3, "Test")
        with self.assertRaises(ValueError):
            extract_context(str(self.pdf), 1, "a" * 2201)

    def test_utf8_json_process_contract(self):
        self.create_pdf([["The bank approved the loan."]])
        worker = Path(__file__).resolve().parents[1] / "src" / "context_worker.py"
        request = json.dumps({"file": str(self.pdf), "page": 1, "selected": "bank"},
                             ensure_ascii=False).encode("utf-8")
        proc = subprocess.run([sys.executable, str(worker)], input=request,
                              capture_output=True, timeout=15, check=True)
        result = json.loads(proc.stdout.decode("utf-8"))
        self.assertTrue(result["ok"])
        self.assertIn("loan", result["candidates"][0]["text"])


if __name__ == "__main__":
    unittest.main()
