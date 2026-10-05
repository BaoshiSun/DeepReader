"""Read a small amount of local PDF context. One JSON request/response, no network."""
from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

import pymupdf

MAX_CONTEXT = 2600
MAX_CANDIDATES = 16


def normalized_with_map(text: str) -> tuple[str, list[int]]:
    """Match PDF ligatures, line wraps and line-end hyphenation without losing offsets."""
    chars: list[str] = []
    offsets: list[int] = []
    skip = set()
    for match in re.finditer(r"(?<=\w)[\-\u00ad]\s*\n\s*(?=\w)", text):
        skip.update(range(match.start(), match.end()))
    for i, char in enumerate(text):
        if i in skip or char == "\u00ad":
            continue
        for normalized in unicodedata.normalize("NFKC", char).casefold():
            if normalized.isspace():
                continue
            chars.append(normalized)
            offsets.append(i)
    return "".join(chars), offsets


def occurrences(text: str, selected: str) -> list[tuple[int, int]]:
    haystack, offsets = normalized_with_map(text)
    needle, _ = normalized_with_map(selected)
    if not needle:
        return []
    results = []
    position = 0
    while (position := haystack.find(needle, position)) >= 0:
        last = position + len(needle) - 1
        start, end = offsets[position], offsets[last] + 1
        # English words must not match the middle of another English word.
        left_ok = not (needle[0].isascii() and needle[0].isalnum()
                       and start > 0 and text[start - 1].isascii()
                       and text[start - 1].isalnum())
        right_ok = not (needle[-1].isascii() and needle[-1].isalnum()
                        and end < len(text) and text[end].isascii()
                        and text[end].isalnum())
        if left_ok and right_ok:
            results.append((start, end))
        position += max(1, len(needle))
    return results


def bounded_context(text: str, start: int, end: int) -> str:
    if end - start > MAX_CONTEXT:
        raise ValueError("选中文字过长，请缩小到一个词、句子或段落。")
    remaining = MAX_CONTEXT - (end - start)
    lo = max(0, start - remaining // 2)
    hi = min(len(text), lo + MAX_CONTEXT)
    lo = max(0, hi - MAX_CONTEXT)
    # The marker identifies the chosen occurrence when a word has several senses.
    result = (text[lo:start] + "⟦" + text[start:end] + "⟧" + text[end:hi]).strip()
    return ("…" if lo else "") + result + ("…" if hi < len(text) else "")


def same_column(a: tuple, b: tuple) -> bool:
    overlap = min(a[2], b[2]) - max(a[0], b[0])
    return overlap >= min(a[2] - a[0], b[2] - b[0]) * 0.55


def block_context(blocks: list[tuple], index: int) -> str:
    block = blocks[index]
    previous = [b for b in blocks if b[3] <= block[1] + 2
                and 0 <= block[1] - b[3] < 150 and same_column(b, block)]
    following = [b for b in blocks if b[1] >= block[3] - 2
                 and 0 <= b[1] - block[3] < 150 and same_column(b, block)]
    pieces = []
    if previous:
        pieces.append(max(previous, key=lambda b: b[3])[4])
    pieces.append(block[4])
    if following:
        pieces.append(min(following, key=lambda b: b[1])[4])
    return "\n\n".join(pieces)


def candidates_on_page(doc, page_index: int, selected: str) -> list[dict]:
    blocks = [b for b in doc[page_index].get_text("blocks", sort=True)
              if b[6] == 0 and b[4].strip()]
    candidates = []
    for i, block in enumerate(blocks):
        matches = occurrences(block[4], selected)
        if not matches:
            continue
        text = block_context(blocks, i)
        # Use the offset in this particular block, not an occurrence in its neighbour.
        offset = text.find(block[4])
        for start, end in matches:
            context = bounded_context(text, offset + start, offset + end)
            preview_text = (block[4][max(0, start - 45):start] + "⟦" + block[4][start:end]
                            + "⟧" + block[4][end:end + 65])
            preview = re.sub(r"\s+", " ", preview_text)
            candidates.append({"page": page_index + 1, "text": context,
                               "label": f"第 {page_index + 1} 页 · {preview[:140]}"})
    # Sentences can span PDF blocks. Keep this fallback only when individual blocks failed.
    if not candidates:
        combined = "\n\n".join(b[4] for b in blocks)
        for start, end in occurrences(combined, selected):
            context = bounded_context(combined, start, end)
            candidates.append({"page": page_index + 1, "text": context,
                               "label": f"第 {page_index + 1} 页 · 跨段落选文"})
    return candidates


def extract_context(file: str, page: int, selected: str) -> dict:
    path = Path(file)
    if not path.is_file():
        raise ValueError("找不到当前 PDF 文件，请确认文件仍在原位置。")
    if path.suffix.lower() != ".pdf":
        raise ValueError("此版本支持 PDF，请将文章转换为 PDF 后使用。")
    if not selected.strip():
        raise ValueError("请先在 PDF 正文中选择一个词或句子。")
    if len(selected) > 2200:
        raise ValueError("选中文字过长，请缩小到一个词、句子或段落。")
    with pymupdf.open(path) as doc:
        if doc.needs_pass:
            raise ValueError("此 PDF 有打开密码，请先保存一份已解密的副本。")
        if not 1 <= page <= len(doc):
            raise ValueError("当前页码无效，请重新在 SumatraPDF 中触发快捷键。")
        current = page - 1
        candidates = candidates_on_page(doc, current, selected)
        # In continuous/facing mode the selected page can differ from the current page.
        if not candidates:
            for index in (current - 1, current + 1):
                if 0 <= index < len(doc):
                    candidates.extend(candidates_on_page(doc, index, selected))
        if not candidates:
            # Handle a sentence selected across a page boundary.
            for index in (current - 1, current):
                if 0 <= index and index + 1 < len(doc):
                    a = doc[index].get_text(sort=True)[-MAX_CONTEXT:]
                    b = doc[index + 1].get_text(sort=True)[:MAX_CONTEXT]
                    combined = a + "\n" + b
                    for start, end in occurrences(combined, selected):
                        candidates.append({"page": index + 1,
                                           "text": bounded_context(combined, start, end),
                                           "label": f"第 {index + 1}–{index + 2} 页 · 跨页选文"})
        unique = []
        seen = set()
        for candidate in candidates:
            identity = (candidate["page"], candidate["text"])
            if identity not in seen:
                unique.append(candidate)
                seen.add(identity)
        return {"ok": True, "candidates": unique[:MAX_CANDIDATES],
                "truncated": len(unique) > MAX_CANDIDATES,
                "warning": "" if unique else
                "无法定位选文的上下文。扫描版、公式或特殊排版可能无法提取；请粘贴附近段落后解释。"}


def main() -> None:
    try:
        # Explicit UTF-8 works both in Python and in the packaged Windows worker.
        request = json.loads(sys.stdin.buffer.read().decode("utf-8-sig"))
        result = extract_context(str(request["file"]), int(request["page"]),
                                 str(request["selected"]))
    except ValueError as exc:
        result = {"ok": False, "error": str(exc)}
    except Exception:
        result = {"ok": False, "error": "无法读取 PDF 上下文。文件可能损坏或不受支持。"}
    sys.stdout.buffer.write(json.dumps(result, ensure_ascii=False).encode("utf-8"))


if __name__ == "__main__":
    main()
