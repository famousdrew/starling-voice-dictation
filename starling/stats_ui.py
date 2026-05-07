from __future__ import annotations

import sys
import threading
from datetime import datetime, timezone

from PySide6.QtCore import Qt, QTimer, Signal, QObject
from PySide6.QtGui import QColor, QFont, QPainter, QPen, QBrush
from PySide6.QtWidgets import (
    QApplication,
    QFrame,
    QHBoxLayout,
    QHeaderView,
    QLabel,
    QLineEdit,
    QMainWindow,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QTabWidget,
    QTableWidget,
    QTableWidgetItem,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from .stats import SessionStats

# ── palette ──────────────────────────────────────────────────────────────────
BG = "#0f0f10"
SURFACE = "#1a1a1e"
BORDER = "#2a2a30"
ACCENT = "#4ade80"        # green — matches the tray recording colour
ACCENT_DIM = "#166534"
TEXT = "#f0f0f0"
TEXT_DIM = "#888"
RED = "#f87171"


_STYLE = f"""
QMainWindow, QWidget {{ background: {BG}; color: {TEXT}; font-family: 'Segoe UI', sans-serif; }}
QTabWidget::pane {{ border: 1px solid {BORDER}; border-radius: 6px; }}
QTabBar::tab {{
    background: {SURFACE}; color: {TEXT_DIM}; padding: 8px 20px;
    border-radius: 4px; margin-right: 2px;
}}
QTabBar::tab:selected {{ background: {ACCENT_DIM}; color: {ACCENT}; }}
QFrame#card {{
    background: {SURFACE}; border: 1px solid {BORDER}; border-radius: 8px;
}}
QLabel#stat-value {{ font-size: 32px; font-weight: 700; color: {ACCENT}; }}
QLabel#stat-label {{ font-size: 11px; color: {TEXT_DIM}; letter-spacing: 1px; }}
QLabel#session-transcript {{ color: {TEXT_DIM}; font-size: 12px; padding: 4px 0; }}
QLabel#session-meta {{ color: {TEXT_DIM}; font-size: 11px; }}
QScrollArea {{ border: none; }}
QLineEdit {{
    background: {SURFACE}; border: 1px solid {BORDER}; border-radius: 6px;
    color: {TEXT}; padding: 8px 12px; font-size: 14px;
}}
QPushButton {{
    background: {ACCENT_DIM}; color: {ACCENT}; border: none; border-radius: 6px;
    padding: 8px 20px; font-size: 13px; font-weight: 600;
}}
QPushButton:hover {{ background: #15803d; }}
QPushButton:disabled {{ background: {SURFACE}; color: {TEXT_DIM}; }}
QTextEdit {{
    background: {SURFACE}; border: 1px solid {BORDER}; border-radius: 6px;
    color: {TEXT}; padding: 8px; font-size: 13px;
}}
QTableWidget {{
    background: {SURFACE}; border: 1px solid {BORDER}; border-radius: 6px;
    color: {TEXT}; font-size: 13px; gridline-color: {BORDER};
}}
QTableWidget::item {{ padding: 6px 10px; border: none; }}
QTableWidget::item:selected {{ background: {ACCENT_DIM}; color: {ACCENT}; }}
QHeaderView::section {{
    background: {BG}; color: {TEXT_DIM}; font-size: 11px; letter-spacing: 1px;
    padding: 6px 10px; border: none; border-bottom: 1px solid {BORDER};
}}
"""


# ── helpers ───────────────────────────────────────────────────────────────────

def _card(layout_cls=QVBoxLayout, margins=(16, 16, 16, 16)) -> tuple[QFrame, QVBoxLayout | QHBoxLayout]:
    frame = QFrame()
    frame.setObjectName("card")
    lay = layout_cls(frame)
    lay.setContentsMargins(*margins)
    lay.setSpacing(6)
    return frame, lay


def _label(text: str, obj_name: str = "", parent=None) -> QLabel:
    lbl = QLabel(text, parent)
    if obj_name:
        lbl.setObjectName(obj_name)
    return lbl


# ── bar chart widget ───────────────────────────────────────────────────────────

class BarChart(QWidget):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._data: list[tuple] = []  # (date, words)
        self.setMinimumHeight(140)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)

    def set_data(self, data: list[tuple]) -> None:
        self._data = data
        self.update()

    def paintEvent(self, event) -> None:
        if not self._data:
            return
        p = QPainter(self)
        try:
            p.setRenderHint(QPainter.RenderHint.Antialiasing)

            w, h = self.width(), self.height()
            pad_l, pad_r, pad_t, pad_b = 8, 8, 16, 24

            max_words = max((v for _, v in self._data), default=1) or 1
            n = len(self._data)
            bar_w = max(2, (w - pad_l - pad_r) / n - 2)
            chart_h = h - pad_t - pad_b

            accent = QColor(ACCENT)
            dim = QColor(ACCENT)
            dim.setAlpha(40)

            for i, (day, words) in enumerate(self._data):
                x = pad_l + i * (w - pad_l - pad_r) / n
                bar_h = int(chart_h * words / max_words) if words else 2
                y = pad_t + chart_h - bar_h
                color = accent if words else dim
                p.setBrush(QBrush(color))
                p.setPen(Qt.PenStyle.NoPen)
                p.drawRoundedRect(int(x), y, max(1, int(bar_w)), bar_h, 2, 2)

            # x-axis labels: first, middle, last
            p.setPen(QPen(QColor(TEXT_DIM)))
            font = QFont("Segoe UI", 9)
            p.setFont(font)
            fm = p.fontMetrics()
            for idx in [0, n // 2, n - 1]:
                day = self._data[idx][0]
                label = f"{day.month}/{day.day}" if hasattr(day, "month") else str(day)
                x = pad_l + idx * (w - pad_l - pad_r) / n
                tw = fm.horizontalAdvance(label)
                p.drawText(int(x - tw / 2), h - 4, label)
        finally:
            p.end()


# ── stat card ─────────────────────────────────────────────────────────────────

def _stat_card(value: str, label: str) -> tuple[QFrame, QLabel]:
    frame, lay = _card()
    val_lbl = _label(value, "stat-value")
    val_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
    lbl = _label(label.upper(), "stat-label")
    lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
    lay.addWidget(val_lbl)
    lay.addWidget(lbl)
    return frame, val_lbl


# ── overview tab ──────────────────────────────────────────────────────────────

class OverviewTab(QWidget):
    def __init__(self, stats: SessionStats, parent=None) -> None:
        super().__init__(parent)
        self._stats = stats

        root = QVBoxLayout(self)
        root.setSpacing(12)
        root.setContentsMargins(12, 12, 12, 12)

        # stat row
        stat_row = QHBoxLayout()
        stat_row.setSpacing(10)
        today_frame, self._val_today = _stat_card("0", "words today")
        week_frame, self._val_7d = _stat_card("0", "last 7 days")
        life_frame, self._val_life = _stat_card("0", "lifetime")
        wpm_frame, self._val_wpm = _stat_card("0", "avg wpm")
        for frame in [today_frame, week_frame, life_frame, wpm_frame]:
            stat_row.addWidget(frame)
        root.addLayout(stat_row)

        # chart
        chart_frame, chart_lay = _card()
        chart_title = _label("30-day words", "stat-label")
        chart_lay.addWidget(chart_title)
        self._chart = BarChart()
        chart_lay.addWidget(self._chart)
        root.addWidget(chart_frame)

        root.addStretch()
        self.refresh()

    def refresh(self) -> None:
        s = self._stats
        self._val_today.setText(f"{s.words_today():,}")
        self._val_7d.setText(f"{s.words_last_7_days():,}")
        self._val_life.setText(f"{s.words_lifetime():,}")
        self._val_wpm.setText(str(s.average_wpm()))
        self._chart.set_data(s.words_per_day(30))


# ── sessions tab ──────────────────────────────────────────────────────────────

class SessionsTab(QWidget):
    def __init__(self, stats: SessionStats, parent=None) -> None:
        super().__init__(parent)
        self._stats = stats

        root = QVBoxLayout(self)
        root.setContentsMargins(12, 12, 12, 12)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        self._container = QWidget()
        self._list_lay = QVBoxLayout(self._container)
        self._list_lay.setSpacing(8)
        self._list_lay.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(self._container)
        root.addWidget(scroll)
        self.refresh()

    def refresh(self) -> None:
        # clear
        while self._list_lay.count():
            item = self._list_lay.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        for session in self._stats.recent_sessions(20):
            frame, lay = _card()
            dt = datetime.fromisoformat(session.timestamp).astimezone()
            meta = _label(
                f"{dt.strftime('%b %d %Y  %H:%M')}  ·  "
                f"{session.word_count} words  ·  "
                f"{session.audio_seconds:.1f}s",
                "session-meta",
            )
            transcript = _label(session.transcript, "session-transcript")
            transcript.setWordWrap(True)
            lay.addWidget(meta)
            lay.addWidget(transcript)
            self._list_lay.addWidget(frame)


# ── playground tab ────────────────────────────────────────────────────────────

class PlaygroundTab(QWidget):
    transcribe_requested = Signal(str)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        root = QVBoxLayout(self)
        root.setContentsMargins(12, 12, 12, 12)
        root.setSpacing(10)

        root.addWidget(_label("Paste or type text to test paste injection:"))
        self._input = QLineEdit()
        self._input.setPlaceholderText("Type something here…")
        root.addWidget(self._input)

        btn = QPushButton("Inject text")
        btn.clicked.connect(self._inject)
        root.addWidget(btn)

        root.addSpacing(16)
        root.addWidget(_label("Transcription output will appear here:"))
        self._output = QTextEdit()
        self._output.setReadOnly(True)
        self._output.setPlaceholderText("Transcripts from dictation sessions appear here…")
        root.addWidget(self._output)
        root.addStretch()

    def _inject(self) -> None:
        from . import inject
        text = self._input.text().strip()
        if text:
            inject.paste(text)

    def append_transcript(self, text: str) -> None:
        self._output.append(text)


# ── vocabulary tab ───────────────────────────────────────────────────────────

class VocabularyTab(QWidget):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        root = QVBoxLayout(self)
        root.setContentsMargins(12, 12, 12, 12)
        root.setSpacing(10)

        root.addWidget(_label(
            "Teach Starling how to spell product names and jargon. "
            "The left column is what the model hears; the right column is what gets pasted.",
            "session-meta",
        ))

        self._table = QTableWidget(0, 2)
        self._table.setHorizontalHeaderLabels(["HEARD AS", "PASTES AS"])
        self._table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self._table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self._table.verticalHeader().setVisible(False)
        self._table.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self._table.itemChanged.connect(self._on_change)
        root.addWidget(self._table)

        btn_row = QHBoxLayout()
        add_btn = QPushButton("Add correction")
        add_btn.clicked.connect(self._add_row)
        del_btn = QPushButton("Remove selected")
        del_btn.setStyleSheet(f"background: #3a1a1a; color: {RED};")
        del_btn.clicked.connect(self._remove_selected)
        btn_row.addWidget(add_btn)
        btn_row.addWidget(del_btn)
        btn_row.addStretch()
        root.addLayout(btn_row)

        self._loading = False
        self._load()

    def _load(self) -> None:
        from . import corrections as corr
        corr.reload()
        self._loading = True
        self._table.setRowCount(0)
        for heard, pastes_as in corr._get():
            self._insert_row(heard, pastes_as)
        self._loading = False

    def _insert_row(self, heard: str = "", pastes_as: str = "") -> None:
        row = self._table.rowCount()
        self._table.insertRow(row)
        self._table.setItem(row, 0, QTableWidgetItem(heard))
        self._table.setItem(row, 1, QTableWidgetItem(pastes_as))

    def _add_row(self) -> None:
        self._insert_row()
        row = self._table.rowCount() - 1
        self._table.editItem(self._table.item(row, 0))

    def _remove_selected(self) -> None:
        rows = sorted({idx.row() for idx in self._table.selectedIndexes()}, reverse=True)
        for row in rows:
            self._table.removeRow(row)
        self._save()

    def _on_change(self, item: QTableWidgetItem) -> None:
        if not self._loading:
            self._save()

    def _save(self) -> None:
        import json, os
        from pathlib import Path
        from . import corrections as corr
        data: dict[str, str] = {}
        for row in range(self._table.rowCount()):
            heard_item = self._table.item(row, 0)
            paste_item = self._table.item(row, 1)
            heard = (heard_item.text().strip().lower() if heard_item else "")
            pastes_as = (paste_item.text().strip() if paste_item else "")
            if heard and pastes_as:
                data[heard] = pastes_as
        path = Path(os.environ["APPDATA"]) / "Starling" / "corrections.json"
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
        corr.reload()


# ── settings tab ─────────────────────────────────────────────────────────────

class SettingsTab(QWidget):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        root = QVBoxLayout(self)
        root.setContentsMargins(12, 12, 12, 12)
        root.setSpacing(10)

        from . import login_item
        frame, lay = _card()
        lay.addWidget(_label("Launch at Login"))
        self._login_btn = QPushButton(
            "Disable launch at login" if login_item.is_enabled()
            else "Enable launch at login"
        )
        self._login_btn.clicked.connect(self._toggle_login)
        lay.addWidget(self._login_btn)
        root.addWidget(frame)

        quit_frame, quit_lay = _card()
        quit_lay.addWidget(_label("Quit Starling"))
        quit_btn = QPushButton("Quit")
        quit_btn.setStyleSheet(f"background: #3a1a1a; color: {RED};")
        quit_btn.clicked.connect(self._quit)
        quit_lay.addWidget(quit_btn)
        root.addWidget(quit_frame)
        root.addStretch()

    def _toggle_login(self) -> None:
        from . import login_item
        if login_item.is_enabled():
            login_item.disable()
            self._login_btn.setText("Enable launch at login")
        else:
            login_item.enable()
            self._login_btn.setText("Disable launch at login")

    def _quit(self) -> None:
        QApplication.instance().quit()


# ── main window ───────────────────────────────────────────────────────────────

class StatsWindow(QMainWindow):
    def __init__(self, stats: SessionStats) -> None:
        super().__init__()
        self.setWindowTitle("Starling")
        self.resize(700, 520)
        self.setStyleSheet(_STYLE)

        tabs = QTabWidget()
        self._overview = OverviewTab(stats)
        self._sessions = SessionsTab(stats)
        self._playground = PlaygroundTab()
        self._vocabulary = VocabularyTab()
        self._settings = SettingsTab()

        tabs.addTab(self._overview, "Overview")
        tabs.addTab(self._sessions, "Sessions")
        tabs.addTab(self._playground, "Playground")
        tabs.addTab(self._vocabulary, "Vocabulary")
        tabs.addTab(self._settings, "Settings")

        tabs.currentChanged.connect(self._on_tab_changed)
        self.setCentralWidget(tabs)
        self._tabs = tabs

    def _on_tab_changed(self, idx: int) -> None:
        if idx == 0:
            self._overview.refresh()
        elif idx == 1:
            self._sessions.refresh()
        elif idx == 3:
            self._vocabulary._load()

    def append_transcript(self, text: str) -> None:
        self._playground.append_transcript(text)


# ── app singleton ─────────────────────────────────────────────────────────────

_app: QApplication | None = None
_window: StatsWindow | None = None
_stats_ref: SessionStats | None = None


class _Bridge(QObject):
    show_signal = Signal()
    transcript_signal = Signal(str)


_bridge: _Bridge | None = None


def init(stats: SessionStats) -> None:
    global _app, _window, _stats_ref, _bridge
    _stats_ref = stats
    _app = QApplication.instance() or QApplication(sys.argv)
    _app.setQuitOnLastWindowClosed(False)
    _window = StatsWindow(stats)
    _bridge = _Bridge()
    _bridge.show_signal.connect(_show)
    _bridge.transcript_signal.connect(_window.append_transcript)


def _show() -> None:
    if _window:
        _window.show()
        _window.raise_()
        _window.activateWindow()


def show() -> None:
    if _bridge:
        _bridge.show_signal.emit()


def notify_transcript(text: str) -> None:
    if _bridge:
        _bridge.transcript_signal.emit(text)


def run_event_loop() -> None:
    if _app:
        _app.exec()
