import os
import sys
import traceback

import numpy as np

from .constants import MODEL_ID, PREWARM_SAMPLES


class ParakeetTranscriber:
    def __init__(self) -> None:
        self._model = None

    def load(self) -> None:
        try:
            print("[transcriber] importing torch...", file=sys.stderr, flush=True)
            import torch
            print(f"[transcriber] torch {torch.__version__}, CUDA available: {torch.cuda.is_available()}", file=sys.stderr, flush=True)
            if torch.cuda.is_available():
                print(f"[transcriber] GPU: {torch.cuda.get_device_name(0)}", file=sys.stderr, flush=True)

            print("[transcriber] importing nemo.collections.asr...", file=sys.stderr, flush=True)
            import nemo.collections.asr as nemo_asr
            print(f"[transcriber] nemo imported OK. Loading {MODEL_ID} ...", file=sys.stderr, flush=True)

            self._model = nemo_asr.models.ASRModel.from_pretrained(MODEL_ID)
            self._model.eval()
            print("[transcriber] model loaded — pre-warming...", file=sys.stderr, flush=True)
            self.transcribe(np.zeros(PREWARM_SAMPLES, dtype=np.float32))
            print("Pre-warm complete. Ready.", file=sys.stderr, flush=True)
        except Exception:
            traceback.print_exc()
            print("[transcriber] model load failed — transcription disabled.", file=sys.stderr, flush=True)

    def transcribe(self, samples: np.ndarray) -> str:
        if self._model is None:
            return ""
        # NeMo ASRModel.transcribe accepts a list of numpy arrays or file paths.
        results = self._model.transcribe([samples])
        if not results:
            return ""
        r = results[0]
        text = r.text if hasattr(r, "text") else str(r)
        return text.strip()
