import json
import os
import uuid
from dataclasses import asdict, dataclass
from datetime import date, datetime, timezone
from pathlib import Path


@dataclass
class SessionRecord:
    id: str
    timestamp: str  # ISO-8601
    audio_seconds: float
    word_count: int
    transcript: str


def _stats_path() -> Path:
    base = Path(os.environ["APPDATA"]) / "Starling"
    base.mkdir(parents=True, exist_ok=True)
    return base / "stats.json"


def _load(path: Path) -> list[SessionRecord]:
    if not path.exists():
        return []
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        return [SessionRecord(**r) for r in raw]
    except Exception:
        return []


def _save(sessions: list[SessionRecord], path: Path) -> None:
    path.write_text(
        json.dumps([asdict(s) for s in sessions], indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


class SessionStats:
    def __init__(self) -> None:
        self._path = _stats_path()
        self.sessions: list[SessionRecord] = _load(self._path)

    def record(self, audio_seconds: float, transcript: str) -> SessionRecord | None:
        text = transcript.strip()
        if not text:
            return None
        words = len(text.split())
        session = SessionRecord(
            id=str(uuid.uuid4()),
            timestamp=datetime.now(timezone.utc).isoformat(),
            audio_seconds=audio_seconds,
            word_count=words,
            transcript=text,
        )
        self.sessions.append(session)
        _save(self.sessions, self._path)
        return session

    # --- aggregates ---

    def _today_start(self) -> datetime:
        today = date.today()
        return datetime(today.year, today.month, today.day, tzinfo=timezone.utc)

    def words_today(self) -> int:
        cutoff = self._today_start()
        return sum(
            s.word_count for s in self.sessions
            if datetime.fromisoformat(s.timestamp) >= cutoff
        )

    def words_last_7_days(self) -> int:
        from datetime import timedelta
        cutoff = datetime.now(timezone.utc) - timedelta(days=7)
        return sum(
            s.word_count for s in self.sessions
            if datetime.fromisoformat(s.timestamp) >= cutoff
        )

    def words_lifetime(self) -> int:
        return sum(s.word_count for s in self.sessions)

    def average_wpm(self) -> int:
        total_sec = sum(s.audio_seconds for s in self.sessions)
        if total_sec <= 0:
            return 0
        return int(self.words_lifetime() / (total_sec / 60))

    def words_per_day(self, days: int = 30) -> list[tuple[date, int]]:
        from datetime import timedelta
        from collections import defaultdict
        totals: dict[date, int] = defaultdict(int)
        for s in self.sessions:
            day = datetime.fromisoformat(s.timestamp).date()
            totals[day] += s.word_count
        today = date.today()
        return [(today - timedelta(days=i), totals.get(today - timedelta(days=i), 0))
                for i in range(days - 1, -1, -1)]

    def recent_sessions(self, n: int = 10) -> list[SessionRecord]:
        return list(reversed(self.sessions[-n:]))
