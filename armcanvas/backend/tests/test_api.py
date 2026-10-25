import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import os
import tempfile

os.environ["LEADERBOARD_FILE"] = os.path.join(tempfile.mkdtemp(), "lb.json")

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health():
    assert client.get("/health").json() == {"ok": True}


def test_plan_endpoint_returns_app_shape():
    body = {"templates": [{"template_id": "circle", "default_target_m": 0.5}, {"template_id": "figure8", "default_target_m": 0.6}, {"template_id": "spiral", "default_target_m": 0.4}]}
    resp = client.post("/plan", json=body)
    assert resp.status_code == 200
    plan = resp.json()
    assert {"items", "estimatedMinutes", "source"} <= plan.keys()
    assert {"templateID", "reps", "targetExtentMeters", "reason"} <= plan["items"][0].keys()


def test_plan_rejects_bad_input():
    assert client.post("/plan", json={"templates": []}).status_code == 422


def test_scores_roundtrip_and_ranking():
    e1 = {"id": "a", "player": "Ann", "templateID": "circle", "total": 70, "extentMeters": 0.5, "date": "2026-10-24T20:00:00Z"}
    e2 = {"id": "b", "player": "Bo", "templateID": "circle", "total": 90, "extentMeters": 0.6, "date": "2026-10-24T20:01:00Z"}
    assert client.post("/scores", json=e1).status_code == 201
    assert client.post("/scores", json=e2).status_code == 201
    assert client.post("/scores", json=e2).status_code == 201  # idempotent
    top = client.get("/scores", params={"template_id": "circle"}).json()
    assert [t["player"] for t in top] == ["Bo", "Ann"]


def test_judge_without_key_is_502(monkeypatch):
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    body = {"template_name": "Big circle", "instruction": "x", "images_png_b64": ["aGk="]}
    assert client.post("/judge", json=body).status_code == 502
