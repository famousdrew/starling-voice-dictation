import sys
import threading

import numpy as np

from .audio import AudioRecorder
from .hotkey import HotkeyEvent, HotkeyMonitor
from .inject import paste
from .stats import SessionStats
from .streaming import StreamingTranscriber
from .transcriber import ParakeetTranscriber
from .tray import TrayIcon, TrayState
from . import stats_ui, corrections


def main() -> None:
    try:
        stats = SessionStats()
        transcriber = ParakeetTranscriber()
        tray = TrayIcon(
            on_stats=stats_ui.show,
            on_dictionary=lambda: stats_ui.show(stats_ui.TAB_VOCABULARY),
            on_settings=lambda: stats_ui.show(stats_ui.TAB_SETTINGS),
            on_quit=_quit,
        )

        recorder = AudioRecorder(on_level=tray.set_level)

        state: dict = {
            "streamer": None,
            "pump_stop": threading.Event(),
            "pump_thread": None,
        }

        def begin_recording(hands_free: bool) -> None:
            recorder.start()
            tray.set_state(TrayState.HANDS_FREE if hands_free else TrayState.RECORDING)
            streamer = StreamingTranscriber(transcriber)
            state["streamer"] = streamer
            stop_event = threading.Event()
            state["pump_stop"] = stop_event

            def pump():
                while not stop_event.wait(timeout=1.0):
                    streamer.extend(recorder.snapshot())

            t = threading.Thread(target=pump, daemon=True)
            state["pump_thread"] = t
            t.start()

        def end_recording(transcribe: bool) -> None:
            state["pump_stop"].set()
            samples = recorder.stop()
            tray.set_state(TrayState.IDLE)
            streamer = state["streamer"]
            state["streamer"] = None
            if not transcribe or streamer is None:
                return
            if samples.size < 1600:
                return
            threading.Thread(
                target=_finalize, args=(samples, streamer, stats), daemon=True
            ).start()

        def on_hotkey(event: HotkeyEvent) -> None:
            if event == HotkeyEvent.START_RECORD:
                begin_recording(hands_free=False)
            elif event == HotkeyEvent.START_HANDS_FREE:
                begin_recording(hands_free=True)
            elif event == HotkeyEvent.STOP_RECORD:
                end_recording(transcribe=True)
            elif event == HotkeyEvent.STOP_CANCEL:
                end_recording(transcribe=False)

        hotkey = HotkeyMonitor(on_event=on_hotkey)

        threading.Thread(
            target=transcriber.load,
            kwargs={"on_status": stats_ui.splash_status, "on_ready": stats_ui.splash_ready},
            daemon=True,
        ).start()
        stats_ui.init(stats)
        tray.start()
        hotkey.start()
        stats_ui.run_event_loop()
        hotkey.stop()
        tray.stop()
    except Exception:
        import traceback
        traceback.print_exc()
        input("Press Enter to exit...")  # keep window open


def _finalize(
    samples: np.ndarray,
    streamer: StreamingTranscriber,
    stats: SessionStats,
) -> None:
    text = corrections.apply(streamer.finalize(samples))
    if not text:
        return
    audio_seconds = samples.size / 16_000
    paste(text + " ")
    stats.record(audio_seconds, text)
    stats_ui.notify_transcript(text)


def _quit() -> None:
    from PySide6.QtWidgets import QApplication
    app = QApplication.instance()
    if app:
        app.quit()


if __name__ == "__main__":
    main()
