import threading
import time
from collections.abc import Callable
from enum import Enum, auto

from pynput import keyboard

from .constants import DOUBLE_TAP_WINDOW, TAP_MAX_DURATION


class HotkeyEvent(Enum):
    START_RECORD = auto()
    START_HANDS_FREE = auto()
    STOP_RECORD = auto()       # transcribe
    STOP_CANCEL = auto()       # discard


class HotkeyMonitor:
    def __init__(self, on_event: Callable[[HotkeyEvent], None]) -> None:
        self._on_event = on_event
        self._lock = threading.Lock()
        self._is_held = False
        self._is_hands_free = False
        self._ignore_next = False
        self._press_time: float = 0.0
        self._last_tap_end: float = 0.0
        self._listener: keyboard.Listener | None = None

    def start(self) -> None:
        self._listener = keyboard.Listener(
            on_press=self._on_press,
            on_release=self._on_release,
            suppress=False,
        )
        self._listener.start()

    def stop(self) -> None:
        if self._listener:
            self._listener.stop()

    def _on_press(self, key: keyboard.Key | keyboard.KeyCode | None) -> bool | None:
        if key != keyboard.Key.ctrl_r:
            with self._lock:
                if self._is_hands_free:
                    self._is_hands_free = False
                    self._on_event(HotkeyEvent.STOP_RECORD)
                    return False  # suppress the key
            return None

        with self._lock:
            if self._ignore_next:
                self._ignore_next = False
                return None

            if self._is_hands_free:
                self._is_hands_free = False
                self._ignore_next = True
                self._on_event(HotkeyEvent.STOP_RECORD)
                return None

            if not self._is_held:
                self._is_held = True
                self._press_time = time.monotonic()
                self._on_event(HotkeyEvent.START_RECORD)

        return None

    def _on_release(self, key: keyboard.Key | keyboard.KeyCode | None) -> bool | None:
        if key != keyboard.Key.ctrl_r:
            return None

        with self._lock:
            if self._ignore_next:
                self._ignore_next = False
                return None

            if not self._is_held:
                return None

            self._is_held = False
            now = time.monotonic()
            duration = now - self._press_time

            if duration < TAP_MAX_DURATION:
                self._on_event(HotkeyEvent.STOP_CANCEL)
                if now - self._last_tap_end < DOUBLE_TAP_WINDOW:
                    self._last_tap_end = 0.0
                    self._is_hands_free = True
                    self._on_event(HotkeyEvent.START_HANDS_FREE)
                else:
                    self._last_tap_end = now
            else:
                self._last_tap_end = 0.0
                self._on_event(HotkeyEvent.STOP_RECORD)

        return None
