"""Shared leaderboard. Stored as one JSON blob in a GCS bucket when
LEADERBOARD_BUCKET is set, otherwise in a local file for development."""
from __future__ import annotations

import json
import os
import threading
from pathlib import Path

from models import ScoreEntry

_LOCK = threading.Lock()
_LOCAL_PATH = Path(os.environ.get("LEADERBOARD_FILE", "leaderboard.json"))
_BUCKET = os.environ.get("LEADERBOARD_BUCKET")
_BLOB = "leaderboard.json"
MAX_ENTRIES = 5000


def _load() -> list[dict]:
    if _BUCKET:
        from google.cloud import storage

        blob = storage.Client().bucket(_BUCKET).blob(_BLOB)
        if not blob.exists():
            return []
        return json.loads(blob.download_as_text())
    if not _LOCAL_PATH.exists():
        return []
    return json.loads(_LOCAL_PATH.read_text())


def _save(entries: list[dict]) -> None:
    payload = json.dumps(entries)
    if _BUCKET:
        from google.cloud import storage

        storage.Client().bucket(_BUCKET).blob(_BLOB).upload_from_string(payload, content_type="application/json")
        return
    _LOCAL_PATH.write_text(payload)


def add(entry: ScoreEntry) -> None:
    with _LOCK:
        entries = _load()
        if any(e["id"] == entry.id for e in entries):
            return
        entries.append(entry.model_dump())
        _save(entries[-MAX_ENTRIES:])


def top(template_id: str, limit: int = 20) -> list[ScoreEntry]:
    with _LOCK:
        entries = [ScoreEntry(**e) for e in _load() if e["templateID"] == template_id]
    entries.sort(key=lambda e: (-e.total, e.date))
    return entries[:limit]
