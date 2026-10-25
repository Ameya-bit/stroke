"""CP-SAT session planner.

Chooses which drawings to do, how many reps, and whether to step the size
target up, subject to time, fatigue, variety and progression constraints.

Decision variables per drawing t:
  reps[t]      integer 0..MAX_REPS_PER_DRAWING
  chosen[t]    reps[t] >= MIN_REPS_IF_CHOSEN  <=>  chosen[t]
  level[t]     target step: 0 hold, 1 = +5%, 2 = +10%

Constraints:
  sum reps * seconds_per_rep <= time budget
  sum reps <= max_total_reps                      (fatigue)
  MIN_DRAWINGS <= sum chosen <= MAX_DRAWINGS      (variety)
  level[t] <= 2 * chosen[t]                       (only progress what you do)
  level[t] <= readiness[t]                        (no progression below READY_SCORE,
                                                   at most one step below STRONG_SCORE,
                                                   none while the movement is fragmented:
                                                   motion ratio > MAX_MOTION_RATIO_TO_PROGRESS)

Objective (maximize):
  sum reps[t] * need[t]  +  sum level[t] * PROGRESS_BONUS
  need[t] = (100 - recent_avg) + novelty(days since last) + BASELINE_BONUS if never tried
            + excess motions: (motion ratio - 1) * MOTION_NEED_PER_UNIT, capped
"""
from __future__ import annotations

from ortools.sat.python import cp_model

from models import PlanItem, PlanRequest, SessionPlan, TemplateStats

MIN_DRAWINGS = 3
MAX_DRAWINGS = 4
MIN_REPS_IF_CHOSEN = 2
MAX_REPS_PER_DRAWING = 4
READY_SCORE = 60
STRONG_SCORE = 80
PROGRESS_BONUS = 15
BASELINE_BONUS = 40
NOVELTY_PER_DAY = 5
NOVELTY_CAP = 25
STEP_FRACTION = 0.05
# Progression is withheld while a drawing takes more than this many times
# the sub-movements it should; bigger is not better if it is done in pieces.
MAX_MOTION_RATIO_TO_PROGRESS = 2.0
MOTION_NEED_PER_UNIT = 20
MOTION_NEED_CAP = 40
MIN_TARGET_FRACTION = 0.6
SOLVER_TIME_LIMIT_S = 2.0


def _need(stats: TemplateStats) -> int:
    if stats.recent_avg_score is None:
        return BASELINE_BONUS + 50
    novelty = min(NOVELTY_CAP, int((stats.days_since_last or 0) * NOVELTY_PER_DAY))
    return int(100 - stats.recent_avg_score) + novelty + _excess_motion_need(stats)


def _excess_motion_need(stats: TemplateStats) -> int:
    if stats.recent_motion_ratio is None:
        return 0
    return min(MOTION_NEED_CAP, int(max(0.0, stats.recent_motion_ratio - 1) * MOTION_NEED_PER_UNIT))


def _is_fragmented(stats: TemplateStats) -> bool:
    return stats.recent_motion_ratio is not None and stats.recent_motion_ratio > MAX_MOTION_RATIO_TO_PROGRESS


def _readiness(stats: TemplateStats) -> int:
    if stats.recent_avg_score is None or _is_fragmented(stats):
        return 0
    if stats.recent_avg_score >= STRONG_SCORE:
        return 2
    if stats.recent_avg_score >= READY_SCORE:
        return 1
    return 0


def _target(stats: TemplateStats, level: int, reach_cap: float | None) -> float:
    base = stats.recent_best_extent_m or stats.default_target_m
    base = max(base, stats.default_target_m * MIN_TARGET_FRACTION)
    target = base * (1 + STEP_FRACTION * level)
    if reach_cap:
        target = min(target, reach_cap)
    return round(target, 2)


def _reason(stats: TemplateStats, level: int) -> str:
    if stats.recent_avg_score is None:
        return "New drawing — set a baseline"
    step = {0: "hold size", 1: "+5% size", 2: "+10% size"}[level]
    if _is_fragmented(stats):
        return f"Recent avg {stats.recent_avg_score:.0f} · {stats.recent_motion_ratio:.1f}× the motions · one sweep first"
    return f"Recent avg {stats.recent_avg_score:.0f} · {step}"


def make_plan(req: PlanRequest) -> SessionPlan:
    model = cp_model.CpModel()
    n = len(req.templates)
    reps = [model.NewIntVar(0, MAX_REPS_PER_DRAWING, f"reps{i}") for i in range(n)]
    chosen = [model.NewBoolVar(f"chosen{i}") for i in range(n)]
    level = [model.NewIntVar(0, 2, f"level{i}") for i in range(n)]

    for i, stats in enumerate(req.templates):
        model.Add(reps[i] >= MIN_REPS_IF_CHOSEN).OnlyEnforceIf(chosen[i])
        model.Add(reps[i] == 0).OnlyEnforceIf(chosen[i].Not())
        model.Add(level[i] <= 2 * chosen[i])
        model.Add(level[i] <= _readiness(stats))

    model.Add(sum(reps) * req.seconds_per_rep <= req.time_budget_s)
    model.Add(sum(reps) <= req.max_total_reps)
    model.Add(sum(chosen) >= min(MIN_DRAWINGS, n))
    model.Add(sum(chosen) <= MAX_DRAWINGS)

    needs = [_need(s) for s in req.templates]
    model.Maximize(
        sum(reps[i] * needs[i] for i in range(n)) + sum(level[i] * PROGRESS_BONUS for i in range(n))
    )

    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = SOLVER_TIME_LIMIT_S
    status = solver.Solve(model)
    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        raise RuntimeError(f"planner infeasible: {solver.StatusName(status)}")

    items = [
        PlanItem(
            templateID=s.template_id,
            reps=solver.Value(reps[i]),
            targetExtentMeters=_target(s, solver.Value(level[i]), req.reach_cap_m),
            reason=_reason(s, solver.Value(level[i])),
        )
        for i, s in enumerate(req.templates)
        if solver.Value(chosen[i])
    ]
    items.sort(key=lambda it: -needs[[s.template_id for s in req.templates].index(it.templateID)])
    total_reps = sum(it.reps for it in items)
    return SessionPlan(
        items=items,
        estimatedMinutes=max(1, round(total_reps * req.seconds_per_rep / 60)),
        source=f"cp-sat ({solver.StatusName(status).lower()}, {solver.WallTime():.2f}s)",
    )
