"""ArmCanvas backend: CP-SAT session planner, Gemini proxy, shared leaderboard."""
from __future__ import annotations

import logging

from fastapi import FastAPI, HTTPException, Query

import judge as judge_module
import leaderboard
from models import JudgeRequest, JudgeResult, PlanRequest, ScoreEntry, SessionPlan
from planner import make_plan

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("armcanvas")

app = FastAPI(title="ArmCanvas backend", version="0.1.0")


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.post("/plan", response_model=SessionPlan)
def plan(req: PlanRequest) -> SessionPlan:
    try:
        return make_plan(req)
    except RuntimeError as exc:
        log.error("plan failed: %s", exc)
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/judge", response_model=JudgeResult)
async def judge(req: JudgeRequest) -> JudgeResult:
    try:
        return await judge_module.judge(req)
    except (RuntimeError, KeyError, ValueError) as exc:
        log.error("judge failed: %s", exc)
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.post("/scores", status_code=201)
def add_score(entry: ScoreEntry) -> dict:
    leaderboard.add(entry)
    return {"ok": True}


@app.get("/scores", response_model=list[ScoreEntry])
def scores(template_id: str = Query(min_length=1), limit: int = Query(default=20, ge=1, le=100)) -> list[ScoreEntry]:
    return leaderboard.top(template_id, limit)
