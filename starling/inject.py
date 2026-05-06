import threading
import time

import win32clipboard
from pynput.keyboard import Controller, Key

from .constants import CLIPBOARD_RESTORE_DELAY

_kb = Controller()


def _send_ctrl_v() -> None:
    with _kb.pressed(Key.ctrl):
        _kb.press('v')
        _kb.release('v')


def _clipboard_get() -> str | None:
    try:
        win32clipboard.OpenClipboard()
        try:
            if win32clipboard.IsClipboardFormatAvailable(win32clipboard.CF_UNICODETEXT):
                return win32clipboard.GetClipboardData(win32clipboard.CF_UNICODETEXT)
        finally:
            win32clipboard.CloseClipboard()
    except Exception:
        pass
    return None


def _clipboard_set(text: str) -> None:
    win32clipboard.OpenClipboard()
    try:
        win32clipboard.EmptyClipboard()
        win32clipboard.SetClipboardData(win32clipboard.CF_UNICODETEXT, text)
    finally:
        win32clipboard.CloseClipboard()


def paste(text: str) -> None:
    previous = _clipboard_get()
    _clipboard_set(text)
    _send_ctrl_v()

    def restore():
        time.sleep(CLIPBOARD_RESTORE_DELAY)
        if previous is not None:
            try:
                _clipboard_set(previous)
            except Exception:
                pass

    threading.Thread(target=restore, daemon=True).start()
