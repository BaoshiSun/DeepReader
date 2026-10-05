"""Verify actual PDF mutations made by NativeIntegration, using only synthetic files."""
from pathlib import Path
import pymupdf

ROOT = Path(__file__).resolve().parents[1] / "artifacts"
for name, highlighted in [("highlight-added.pdf", True), ("highlight-removed.pdf", False)]:
    with pymupdf.open(ROOT / name) as doc:
        page = doc[0]
        annotations = list(page.annots() or [])
        foreign = [a for a in annotations if a.info["content"] == "Unrelated fixture annotation"]
        own = [a for a in annotations if a.info["id"].startswith("DeepReader:v1:")]
        assert len(foreign) == 1, f"{name}: unrelated annotation must survive"
        assert len(annotations) == (2 if highlighted else 1), f"{name}: unexpected annotation count"
        if highlighted:
            assert len(own) == 1 and own[0].type[0] == pymupdf.PDF_ANNOT_HIGHLIGHT
            annot = own[0]
            assert annot.info["content"] == "DeepReader: bank approved a loan"
            assert annot.colors["stroke"][1] > annot.colors["stroke"][0], "highlight must be green"
            # The live selection was changed to the first 'bank' before highlighting.
            # Its stored quads must still mark the captured phrase at the second occurrence.
            bounds = pymupdf.Quad(annot.vertices[:4]).rect
            expected = page.search_for("bank approved a loan")[0]
            assert abs(bounds.x0 - expected.x0) < 2 and abs(bounds.x1 - expected.x1) < 2, (bounds, expected)
        else:
            assert not own, "unhighlight must persist after saving"
    print(f"PASS: {name} contains the correct saved annotations and preserves unrelated markup")
