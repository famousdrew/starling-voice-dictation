import json
import os
import re
import sys
from pathlib import Path


def _corrections_path() -> Path:
    return Path(os.environ["APPDATA"]) / "Starling" / "corrections.json"


def _load() -> list[tuple[str, str]]:
    path = _corrections_path()
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return [(k.lower(), v) for k, v in data.items()]
    except Exception as e:
        print(f"[corrections] failed to load: {e}", file=sys.stderr)
        return []


_corrections: list[tuple[str, str]] | None = None


def _get() -> list[tuple[str, str]]:
    global _corrections
    if _corrections is None:
        _corrections = _load()
    return _corrections


def apply(text: str) -> str:
    for pattern, replacement in _get():
        text = re.sub(re.escape(pattern), replacement, text, flags=re.IGNORECASE)
    return text


def reload() -> None:
    global _corrections
    _corrections = None
