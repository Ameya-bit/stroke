import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from models import PlanRequest, TemplateStats
from planner import MAX_DRAWINGS, MIN_DRAWINGS, MIN_REPS_IF_CHOSEN, make_plan

TEMPLATES = [
    TemplateStats(template_id="circle", default_target_m=0.5, recent_avg_score=90, recent_best_extent_m=0.55, attempts=6, days_since_last=0),
    TemplateStats(template_id="figure8", default_target_m=0.6, recent_avg_score=55, recent_best_extent_m=0.4, attempts=3, days_since_last=1),
    TemplateStats(template_id="wallclimb", default_target_m=0.6, recent_avg_score=70, recent_best_extent_m=0.5, attempts=2, days_since_last=3),
    TemplateStats(template_id="sweep", default_target_m=0.7),
    TemplateStats(template_id="spiral", default_target_m=0.4, recent_avg_score=82, recent_best_extent_m=0.38, attempts=4, days_since_last=0),
]


def test_plan_respects_time_and_fatigue_and_variety():
    req = PlanRequest(templates=TEMPLATES, time_budget_s=240, seconds_per_rep=20, max_total_reps=12)
    plan = make_plan(req)
    total = sum(i.reps for i in plan.items)
    assert total * 20 <= 240
    assert total <= 12
    assert MIN_DRAWINGS <= len(plan.items) <= MAX_DRAWINGS
    assert all(i.reps >= MIN_REPS_IF_CHOSEN for i in plan.items)


def test_weak_and_new_drawings_get_volume():
    plan = make_plan(PlanRequest(templates=TEMPLATES))
    ids = {i.templateID for i in plan.items}
    assert "figure8" in ids  # weakest
    assert "sweep" in ids  # never tried


def test_no_progression_below_ready_score():
    plan = make_plan(PlanRequest(templates=TEMPLATES))
    by_id = {i.templateID: i for i in plan.items}
    assert by_id["figure8"].targetExtentMeters <= 0.4  # avg 55: hold


def test_strong_drawing_can_step_up_when_chosen():
    strong_only = [TEMPLATES[0], TEMPLATES[4], TEMPLATES[2]]
    plan = make_plan(PlanRequest(templates=strong_only, time_budget_s=600))
    by_id = {i.templateID: i for i in plan.items}
    assert by_id["circle"].targetExtentMeters > 0.55


def test_reach_cap_limits_target():
    plan = make_plan(PlanRequest(templates=TEMPLATES, reach_cap_m=0.3))
    assert all(i.targetExtentMeters <= 0.3 for i in plan.items)


def test_tight_budget_shrinks_plan():
    plan = make_plan(PlanRequest(templates=TEMPLATES, time_budget_s=120, seconds_per_rep=20))
    assert sum(i.reps for i in plan.items) <= 6


def test_fragmented_strong_drawing_holds_size():
    fragmented = TemplateStats(template_id="circle", default_target_m=0.5, recent_avg_score=90,
                               recent_best_extent_m=0.55, attempts=6, days_since_last=0, recent_motion_ratio=3.0)
    plan = make_plan(PlanRequest(templates=[fragmented, TEMPLATES[4], TEMPLATES[2]], time_budget_s=600))
    by_id = {i.templateID: i for i in plan.items}
    assert by_id["circle"].targetExtentMeters == 0.55
    assert "motions" in by_id["circle"].reason


def test_excess_motions_raise_priority():
    smooth = TemplateStats(template_id="a", default_target_m=0.5, recent_avg_score=80, recent_best_extent_m=0.5, attempts=3, days_since_last=0, recent_motion_ratio=1.0)
    choppy = TemplateStats(template_id="b", default_target_m=0.5, recent_avg_score=80, recent_best_extent_m=0.5, attempts=3, days_since_last=0, recent_motion_ratio=2.5)
    filler = [TemplateStats(template_id=f"f{i}", default_target_m=0.5, recent_avg_score=95, attempts=3, days_since_last=0) for i in range(3)]
    plan = make_plan(PlanRequest(templates=[smooth, choppy, *filler], time_budget_s=180, seconds_per_rep=20))
    by_id = {i.templateID: i.reps for i in plan.items}
    assert by_id.get("b", 0) >= by_id.get("a", 0)
    assert "b" in by_id
