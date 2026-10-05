from pathlib import Path
import pymupdf

target = Path(__file__).resolve().parents[1] / "artifacts" / "语境 smoke.pdf"
target.parent.mkdir(parents=True, exist_ok=True)
with pymupdf.open() as document:
    page = document.new_page()
    page.insert_textbox(pymupdf.Rect(60, 70, 500, 140),
                        "The river bank was steep, but the bank approved a loan.", fontsize=12)
    unrelated = page.add_highlight_annot(page.search_for("steep"))
    unrelated.set_info(content="Unrelated fixture annotation")
    unrelated.update()
    document.save(target)
