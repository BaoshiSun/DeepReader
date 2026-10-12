"""Generate synthetic books. Optionally fetch hash-pinned upstream parser fixtures.

Only --upstream uses the network. Books and user credentials are never collected.
Upstream samples stay in .build and are never included in an application package.
"""
from pathlib import Path
import argparse
import hashlib
import struct
import urllib.request
import urllib.parse
import zipfile

ROOT = Path(__file__).resolve().parents[1] / ".build" / "format-fixtures"
SENTENCE = "The river bank is green. The bank approved the loan."
FILES = {
    "mimetype": "application/epub+zip",
    "META-INF/container.xml": '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OPS/book.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
    "OPS/book.opf": '''<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>DeepReader Format Garden</dc:title><dc:identifier id="id">urn:uuid:deepreader-fixture</dc:identifier><dc:language>en</dc:language></metadata><manifest><item id="later" href="a-last.xhtml" media-type="application/xhtml+xml"/><item id="first" href="z-first.xhtml" media-type="application/xhtml+xml"/><item id="style" href="style.css" media-type="text/css"/><item id="picture" href="leaf.svg" media-type="image/svg+xml"/></manifest><spine><itemref idref="first"/><itemref idref="later"/></spine></package>''',
    "OPS/z-first.xhtml": f'''<html xmlns="http://www.w3.org/1999/xhtml"><head><title>The reading garden</title><link rel="stylesheet" href="style.css"/></head><body><div class="eyebrow">DEEPREADER · EPUB</div><h1>The reading garden</h1><img src="leaf.svg" width="120" height="72" alt="Green leaves"/><p>{SENTENCE}</p><p>A word can change its meaning with the sentence around it. Select the second <strong>bank</strong> to explore the financial meaning.</p><blockquote>阅读应当流畅，解释应当简洁。<br/>Keep reading. Let context do the work.</blockquote><h2>One reader, several formats</h2><p>EPUB · TXT · Markdown · MOBI · AZW3</p><p><a href="a-last.xhtml#ending">Continue to the next chapter →</a></p><script>window.bookScriptRan = true; fetch('https://example.invalid/private')</script><iframe src="https://example.invalid/tracker"></iframe><p onclick="alert(1)">Scripts in books are disabled.</p></body></html>''',
    "OPS/a-last.xhtml": '<html><body><h1 id="ending">The last chapter</h1><p>CHAPTER_TWO_SENTINEL: Every saved lookup is one step in a reading journey.</p><a href="z-first.xhtml">Return to the garden</a></body></html>',
    "OPS/style.css": '.eyebrow {font:12px -apple-system,sans-serif; letter-spacing:3px;color:#4c8765} h1 {color:#286140;font-size:34px} h2 {font-size:22px;color:#38694c}',
    "OPS/leaf.svg": '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="72" viewBox="0 0 120 72"><path d="M58 65C8 58 10 5 10 5c50 0 65 32 48 60Z" fill="#80b898"/><path d="M58 65C45 18 100 6 108 12c-2 35-15 55-50 53Z" fill="#337d54"/></svg>',
}


def epub(name, changes=None, extras=None):
    files = FILES | (changes or {})
    with zipfile.ZipFile(ROOT / name, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path, value in files.items():
            archive.writestr(path, value.encode("utf-8"), compress_type=zipfile.ZIP_STORED if path == "mimetype" else zipfile.ZIP_DEFLATED)
        for path, value in extras or []:
            archive.writestr(path, value)


def make():
    ROOT.mkdir(parents=True, exist_ok=True)
    epub("garden.epub")
    epub("traversal.epub", extras=[("../escape.txt", b"must not extract")])
    epub("missing.epub", {"OPS/book.opf": FILES["OPS/book.opf"].replace('href="z-first.xhtml"', 'href="missing.xhtml"')})
    epub("drm.epub", {"META-INF/encryption.xml": '<encryption><EncryptedData><EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes128-cbc"/></EncryptedData></encryption>'})
    epub("entity.epub", {"META-INF/container.xml": '<!DOCTYPE container [<!ENTITY x SYSTEM "file:///etc/passwd">]><container>&x;</container>'})
    epub("oversize.epub", extras=[("huge.txt", b"A" * (33 * 1024 * 1024))])
    (ROOT / "garden.txt").write_text("阅读花园\n\n" + SENTENCE + "\n中文与 English. 🌱", encoding="utf-8")
    (ROOT / "utf16.txt").write_text("UTF16 中文\n" + SENTENCE, encoding="utf-16")
    (ROOT / "gb18030.txt").write_bytes(("中文编码测试\n" + SENTENCE).encode("gb18030"))
    (ROOT / "garden.md").write_text("# Reading garden\n\n" + SENTENCE + "\n\n- **EPUB** and text\n- Kindle books\n\n> 上下文很重要。\n\n```swift\nlet reading = true\n```\n", encoding="utf-8")
    # A minimal uncompressed PalmDOC (Text/REAd) file is a legacy MOBI input.
    text = ("<html><body><h1>Legacy MOBI</h1><p>" + SENTENCE + "</p></body></html>").encode()
    pdb = bytearray(78)
    name = b"DeepReader MOBI"
    pdb[:len(name)] = name
    pdb[60:68] = b"TEXtREAd"
    struct.pack_into(">H", pdb, 76, 2)
    first = 78 + 16 + 2
    records = struct.pack(">II", first, 0) + struct.pack(">II", first + 16, 2) + b"\0\0"
    header = struct.pack(">HHIHHI", 1, 0, len(text), 1, 4096, 0)
    (ROOT / "garden.mobi").write_bytes(pdb + records + header + text)


UPSTREAM = {
    "sample-cp1252.mobi": "e77aa8f99d65f12bc7b5d71f272a2a4a8f36fe6d5c00e9b95c8a926b145ad088",
    "sample-obfuscated-fonts.mobi": "34fc67043eeeaa6563481d6ea2fea1b5349cb73e459a1f10e3aa09186f56302e",
    "sample-unicode-huffdic.mobi": "560dda58429878a64f73381ffddfcf1a59809e7c669a5222666257df8976a68f",
    "sample-drm_pidLTKULBB^5V-v2.mobi": "73238bbadfc40b5818bd7c872093cd47926ba3dad07d6b12b8dde7185298ee94",
}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream", action="store_true")
    args = parser.parse_args()
    make()
    if args.upstream:
        for name, digest in UPSTREAM.items():
            path = ROOT / ("sample-kf8.azw3" if name == "sample-obfuscated-fonts.mobi" else name)
            if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                url = "https://raw.githubusercontent.com/bfabiszewski/libmobi/85dcfe803fc2a21020ddcf15c3eb66b93d388add/tests/samples/" + urllib.parse.quote(name)
                data = urllib.request.urlopen(url, timeout=40).read()
                if hashlib.sha256(data).hexdigest() != digest:
                    raise ValueError("Upstream fixture checksum mismatch")
                path.write_bytes(data)
    print("Format fixtures prepared in .build/format-fixtures")
