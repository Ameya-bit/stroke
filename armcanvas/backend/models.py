"""Request/response schemas shared by the iOS app and the backend."""
from __future__ import annotations

from pydantic import BaseModel, Field, field_validator

MAX_TEMPLATES = 12
MAX_ID_LEN = 32
MAX_NAME_LEN = 40
MAX_TEXT_LEN = 300
# 3 orthographic PNG snapshots of line art are ~20-80 KB each; cap well above that.
MAX_IMAGE_B64_LEN = 2_000_000


class TemplateStats(BaseModel):
    """Per-drawing history summary the app sends to the planner."""

    template_id: str = Field(min_length=1, max_length=MAX_ID_LEN)
    default_target_m: float = Field(gt=0, le=5)
    recent_avg_score: float | None = Field(default=None, ge=0, le=100)
    recent_best_extent_m: float | None = Field(default=None, ge=0)
    attempts: int = Field(default=0, ge=0)
    days_since_last: float | None = Field(default=None, ge=0)
    # Sub-movements used / sub-movements a clean performance takes; 1.0 is ideal.
    recent_motion_ratio: float | None = Field(default=None, ge=0)


class PlanRequest(BaseModel):
    templates: list[TemplateStats] = Field(min_length=1, max_length=MAX_TEMPLATES)
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
    id: str = Field(min_length=1, max_length=36)
    player: str = Field(min_length=1, max_length=MAX_NAME_LEN)
    templateID: str = Field(min_length=1, max_length=MAX_ID_LEN)
    total: int = Field(ge=0, le=100)
    extentMeters: float = Field(ge=0, le=5)
    date: str = Field(min_length=1, max_length=40)


class JudgeRequest(BaseModel):
    template_name: str = Field(min_length=1, max_length=MAX_NAME_LEN)
    instruction: str = Field(min_length=1, max_length=MAX_TEXT_LEN)
    images_png_b64: list[str] = Field(min_length=1, max_length=4)
    """Each image is capped in the validator below."""

    @field_validator("images_png_b64")
    @classmethod
    def _cap_image_size(cls, images: list[str]) -> list[str]:
        if any(len(img) > MAX_IMAGE_B64_LEN for img in images):
            raise ValueError("image too large")
        return images


class JudgeResult(BaseModel):
    guess: str
    match: int = Field(ge=0, le=10)
    feedback: str
