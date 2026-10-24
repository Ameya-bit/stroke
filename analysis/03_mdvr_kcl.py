"""MDVR-KCL read speech: prosody + perturbation features, PD vs HC, leave-one-speaker-out.

Filenames look like ID34_pd_2_0_0.wav = speaker, label, Hoehn&Yahr, UPDRS II-5, UPDRS III-18.
No age/sex metadata ships with the set, so the age confounder cannot be checked here.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import parselmouth
from scipy.stats import ttest_ind
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import LeaveOneOut, cross_val_predict
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

sys.path.insert(0, str(Path(__file__).parent))
from features import FEATURE_COLUMNS, PITCH_FLOOR_HZ, extract_features  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw/mdvr_kcl/26-29_09_2017_KCL"
OUT = ROOT / "data/processed/mdvr_kcl_features.csv"
PAUSE_DB_BELOW_PEAK = 25.0
MIN_PAUSE_S = 0.15
NAME_RE = re.compile(r"(ID\d+)_(pd|hc)_(\d+)_(\d+)_(\d+)")


def prosody_features(wav: Path) -> dict[str, float]:
    """Pause statistics for connected speech from the intensity contour."""
    snd = parselmouth.Sound(str(wav)).convert_to_mono()
    inten = snd.to_intensity(minimum_pitch=PITCH_FLOOR_HZ)
    vals, times = inten.values[0], inten.xs()
    silent = vals < (np.percentile(vals, 99) - PAUSE_DB_BELOW_PEAK)
    dt = times[1] - times[0]
    # run-length encode silent frames
    pauses = []
    run = 0
    for s in silent:
        run = run + 1 if s else (pauses.append(run * dt) if run else None) or 0
    pauses = [p for p in pauses if p >= MIN_PAUSE_S]
    total = snd.get_total_duration()
    return {
        "pause_fraction": float(silent.mean()),
        "pause_count_per_min": 60.0 * len(pauses) / total,
        "mean_pause_s": float(np.mean(pauses)) if pauses else 0.0,
    }


def main() -> None:
    rows = []
    for task in ("ReadText", "SpontaneousDialogue"):
        for wav in sorted((RAW / task).rglob("*.wav")):
            m = NAME_RE.search(wav.stem)
            if not m:
                print("skip unparsed", wav.name); continue
            sid, lab, hy, u2, u3 = m.groups()
            rows.append({"task": task, "speaker": sid, "label": lab.upper(), "hoehn_yahr": int(hy),
                         "updrs2_5": int(u2), "updrs3_18": int(u3), "file": wav.name,
                         **extract_features(wav), **prosody_features(wav)})
    df = pd.DataFrame(rows)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT, index=False)
    print(f"== {len(df)} recordings, {df.speaker.nunique()} speakers -> {OUT.relative_to(ROOT)}")
    print(df.groupby(["task", "label"]).size().to_string())
    print("sample rates:", sorted(df.sample_rate_hz.unique()), "| duration s: mean", round(df.duration_s.mean(), 1))
    print("\nH&Y stages among PD:", df[df.label == "PD"].drop_duplicates("speaker").hoehn_yahr.value_counts().sort_index().to_dict())

    cols = FEATURE_COLUMNS + ["pause_fraction", "pause_count_per_min", "mean_pause_s"]
    for task in ("ReadText", "SpontaneousDialogue"):
        t = df[df.task == task]
        print(f"\n== {task}: PD vs HC (Welch t)")
        for c in cols:
            a, b = t.loc[t.label == "PD", c].dropna(), t.loc[t.label == "HC", c].dropna()
            p = ttest_ind(a, b, equal_var=False).pvalue
            flag = " *" if p < 0.05 else ""
            print(f"{c:20s} PD={a.mean():9.4f} HC={b.mean():9.4f} p={p:.3f}{flag}")
        y = (t.label == "PD").astype(int).to_numpy()
        X = t[cols].fillna(t[cols].median()).to_numpy()
        model = make_pipeline(StandardScaler(), LogisticRegression(max_iter=5000, C=0.3))
        proba = cross_val_predict(model, X, y, cv=LeaveOneOut(), method="predict_proba")[:, 1]
        print(f"-- LOO logistic (all {len(cols)} features): AUC={roc_auc_score(y, proba):.3f} acc={np.mean((proba > .5) == y):.3f} majority={max(y.mean(), 1 - y.mean()):.3f}")
        pros = ["f0_cv", "f0_std_hz", "intensity_std_db", "pause_fraction", "pause_count_per_min", "mean_pause_s"]
        proba = cross_val_predict(model, t[pros].fillna(0).to_numpy(), y, cv=LeaveOneOut(), method="predict_proba")[:, 1]
        print(f"-- LOO logistic (prosody only): AUC={roc_auc_score(y, proba):.3f} acc={np.mean((proba > .5) == y):.3f}")


if __name__ == "__main__":
    main()
