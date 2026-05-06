import threading
from collections.abc import Callable

import numpy as np
import sounddevice as sd

from .constants import SAMPLE_RATE


class AudioRecorder:
    def __init__(self, on_level: Callable[[float], None] | None = None) -> None:
        self._on_level = on_level
        self._lock = threading.Lock()
        self._buf: list[np.ndarray] = []
        self._stream: sd.InputStream | None = None

    def start(self) -> None:
        with self._lock:
            self._buf.clear()
        self._stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype="float32",
            blocksize=1024,
            callback=self._callback,
        )
        self._stream.start()

    def _callback(
        self,
        indata: np.ndarray,
        frames: int,
        time,
        status,
    ) -> None:
        chunk = indata[:, 0].copy()
        with self._lock:
            self._buf.append(chunk)
        if self._on_level:
            peak = float(np.max(np.abs(chunk)))
            self._on_level(peak)

    def snapshot(self) -> np.ndarray:
        with self._lock:
            if not self._buf:
                return np.zeros(0, dtype=np.float32)
            return np.concatenate(self._buf)

    def stop(self) -> np.ndarray:
        if self._stream:
            self._stream.stop()
            self._stream.close()
            self._stream = None
        return self.snapshot()
