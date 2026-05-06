import queue
import threading

import numpy as np

from .constants import (
    MAX_CHUNK_SECONDS,
    MIN_CHUNK_SECONDS,
    SAMPLE_RATE,
    SILENCE_THRESHOLD,
    SILENCE_WINDOW_MS,
)
from .transcriber import ParakeetTranscriber


class StreamingTranscriber:
    def __init__(self, transcriber: ParakeetTranscriber) -> None:
        self._transcriber = transcriber
        self._min_samples = MIN_CHUNK_SECONDS * SAMPLE_RATE
        self._max_samples = MAX_CHUNK_SECONDS * SAMPLE_RATE
        self._silence_window = SILENCE_WINDOW_MS * SAMPLE_RATE // 1000
        self._consumed = 0
        self._transcripts: list[str] = []
        self._queue: queue.Queue[np.ndarray | None] = queue.Queue()
        self._thread = threading.Thread(target=self._worker, daemon=True)
        self._thread.start()

    def extend(self, buffer: np.ndarray) -> None:
        while True:
            split = self._next_split(buffer)
            if split is None:
                break
            chunk = buffer[self._consumed:split].copy()
            self._consumed = split
            self._queue.put(chunk)

    def finalize(self, buffer: np.ndarray) -> str:
        self.extend(buffer)
        if buffer.size > self._consumed:
            tail = buffer[self._consumed:].copy()
            if tail.size > 1600:
                self._queue.put(tail)
            self._consumed = buffer.size
        self._queue.put(None)  # sentinel
        self._thread.join()
        return " ".join(self._transcripts).strip()

    def _next_split(self, buffer: np.ndarray) -> int | None:
        available = buffer.size - self._consumed
        if available < self._min_samples:
            return None
        if available >= self._max_samples:
            return self._consumed + self._max_samples

        scan_start = self._consumed + self._min_samples
        scan_end = buffer.size - self._silence_window
        if scan_end <= scan_start:
            return None

        step = max(self._silence_window // 2, 1)
        i = scan_start
        while i <= scan_end:
            peak = float(np.max(np.abs(buffer[i:i + self._silence_window])))
            if peak < SILENCE_THRESHOLD:
                return i + self._silence_window // 2
            i += step
        return None

    def _worker(self) -> None:
        while True:
            chunk = self._queue.get()
            if chunk is None:
                break
            text = self._transcriber.transcribe(chunk)
            if text:
                self._transcripts.append(text)
