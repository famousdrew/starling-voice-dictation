from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from PIL import Image

_ASSETS = Path(__file__).parent / "assets"


@lru_cache(maxsize=16)
def app_icon(size: int) -> Image.Image:
    """Return the app icon as a square PIL RGBA image at the requested size.

    The source PNG has a black background outside the circular logo.
    We apply a circular alpha mask so the tray and splash get clean transparency.
    """
    src = Image.open(_ASSETS / "icon.png").convert("RGBA")

    # Crop to the bounding box of the circle by treating the background colour
    # (sampled from the top-left corner) as transparent.  Works for any
    # background -- black, cream, white, etc.
    tmp = src.copy()
    px = tmp.load()
    w, h = tmp.size
    bg_r, bg_g, bg_b, _ = px[0, 0]
    TOL = 30
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if abs(r - bg_r) < TOL and abs(g - bg_g) < TOL and abs(b - bg_b) < TOL:
                px[x, y] = (0, 0, 0, 0)
    bbox = tmp.getbbox()
    if bbox:
        src = src.crop(bbox)

    # Make it square
    side = max(src.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - src.width) // 2
    oy = (side - src.height) // 2
    square.paste(src, (ox, oy))

    # Apply circular alpha mask so black corners become transparent
    import math
    mask = Image.new("L", (side, side), 0)
    cx, cy, r = side / 2, side / 2, side / 2 - 1
    mpx = mask.load()
    for y in range(side):
        for x in range(side):
            if math.hypot(x - cx, y - cy) <= r:
                mpx[x, y] = 255
    square.putalpha(mask)

    return square.resize((size, size), Image.LANCZOS)


def app_icon_ico_path() -> Path:
    """Return path to the multi-size .ico file, generating it if needed."""
    path = _ASSETS / "icon.ico"
    if not path.exists():
        _generate_ico(path)
    return path


def _generate_ico(dest: Path) -> None:
    # Pillow ICO: pass the largest frame as the base and request all sizes;
    # Pillow resizes internally from that source.
    base = app_icon(256)
    base.save(
        dest,
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
