import threading
from collections.abc import Callable
from enum import Enum, auto

from PIL import Image, ImageDraw
import pystray

from .constants import LEVEL_BAR_BIAS, LEVEL_PEAK_GAIN

ICON_SIZE = 64
BAR_COUNT = 5
BAR_W = 8
BAR_GAP = 3
BAR_MAX_H = 40
BAR_Y_BOTTOM = 52


class TrayState(Enum):
    IDLE = auto()
    RECORDING = auto()
    HANDS_FREE = auto()


def _draw_icon(state: TrayState, level: float) -> Image.Image:
    img = Image.new("RGBA", (ICON_SIZE, ICON_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if state == TrayState.IDLE:
        # Filled circle background + bold mic
        cx, cy = ICON_SIZE // 2, ICON_SIZE // 2
        r = 30
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(50, 50, 55, 230))
        # mic capsule (filled)
        draw.rounded_rectangle([cx - 9, cy - 18, cx + 9, cy + 4], radius=9, fill=(200, 200, 200))
        # stand arc
        draw.arc([cx - 15, cy - 6, cx + 15, cy + 16], 0, 180, fill=(200, 200, 200), width=3)
        # stem + base
        draw.line([cx, cy + 16, cx, cy + 23], fill=(200, 200, 200), width=3)
        draw.line([cx - 8, cy + 23, cx + 8, cy + 23], fill=(200, 200, 200), width=3)
        return img

    color = (255, 60, 60) if state == TrayState.HANDS_FREE else (80, 220, 120)

    total_w = BAR_COUNT * BAR_W + (BAR_COUNT - 1) * BAR_GAP
    x0 = (ICON_SIZE - total_w) // 2

    for i in range(BAR_COUNT):
        threshold = (i + 1) / BAR_COUNT * LEVEL_BAR_BIAS
        lit = level >= threshold
        bar_h = max(4, int(BAR_MAX_H * (i + 1) / BAR_COUNT)) if lit else 4
        x = x0 + i * (BAR_W + BAR_GAP)
        y1 = BAR_Y_BOTTOM - bar_h
        alpha = 255 if lit else 80
        draw.rectangle([x, y1, x + BAR_W, BAR_Y_BOTTOM], fill=(*color, alpha))

    return img


class TrayIcon:
    def __init__(
        self,
        on_stats: Callable[[], None],
        on_quit: Callable[[], None],
    ) -> None:
        self._on_stats = on_stats
        self._on_quit = on_quit
        self._state = TrayState.IDLE
        self._level: float = 0.0
        self._lock = threading.Lock()
        self._icon: pystray.Icon | None = None

    def start(self) -> None:
        menu = pystray.Menu(
            pystray.MenuItem("Stats", lambda: self._on_stats()),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit", lambda: self._on_quit()),
        )
        self._icon = pystray.Icon(
            "Starling",
            icon=_draw_icon(TrayState.IDLE, 0.0),
            title="Starling",
            menu=menu,
        )
        threading.Thread(target=self._icon.run, daemon=True).start()

    def set_state(self, state: TrayState, level: float = 0.0) -> None:
        with self._lock:
            self._state = state
            self._level = min(1.0, level * LEVEL_PEAK_GAIN)
        self._update()

    def set_level(self, raw_peak: float) -> None:
        with self._lock:
            if self._state == TrayState.IDLE:
                return
            self._level = min(1.0, raw_peak * LEVEL_PEAK_GAIN)
        self._update()

    def _update(self) -> None:
        if self._icon is None:
            return
        with self._lock:
            state, level = self._state, self._level
        self._icon.icon = _draw_icon(state, level)

    def stop(self) -> None:
        if self._icon:
            self._icon.stop()
