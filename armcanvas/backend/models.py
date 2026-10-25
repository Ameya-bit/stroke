"""Request/response schemas shared by the iOS app and the backend."""
from __future__ import annotations

from pydantic import BaseModel, Field


class TemplateStats(BaseModel):
    """Per-drawing history summary the app sends to the planner."""

    template_id: str
    default_target_m: float = Field(gt=0)
    recent_avg_score: float | None = Field(default=None, ge=0, le=100)
    recent_best_extent_m: float | None = Field(default=None, ge=0)
    attempts: int = Field(default=0, ge=0)
    days_since_last: float | None = Field(default=None, ge=0)
    # Sub-movements used / sub-movements a clean performance takes; 1.0 is ideal.
    recent_motion_ratio: float | None = Field(default=None, ge=0)


class PlanRequest(BaseModel):
    templates: list[TemplateStats] = Field(min_length=1)
    time_budget_s: int = Field(default=480, ge=60, le=3600)
    seconds_per_rep: int = Field(default=20, ge=5, le=120)
    max_total_reps: int = Field(default=12, ge=1, le=60)
    reach_cap_m: float | None = Field(default=None, gt=0)


class PlanItem(BaseModel):
    templateID: str
    reps: int
    targetExtentMeters: float
    reason: str


class SessionPlan(BaseModel):
    items: list[PlanItem]
    estimatedMinutes: int
    source: str


class ScoreEntry(BaseModel):
    id: str
    player: str
    templateID: str
    total: int = Field(ge=0, le=100)
    extentMeters: float = Field(ge=0)
    date: str


class JudgeRequest(BaseModel):
    template_name: str
    instruction: str
    images_png_b64: list[str] = Field(min_length=1, max_length=4)


class JudgeResult(BaseModel):
    guess: str
    match: int = Field(ge=0, le=10)
    feedback: str
