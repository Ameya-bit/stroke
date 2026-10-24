"""Italian Parkinson's Voice and Speech (Dimauro & Girardi): the age-matched test.

28 PD, 22 elderly HC, 15 young HC. 16 kHz PCM. Filenames encode task, speaker
id, birth year and sex: VA1 ACNAGRER 49 F 21032017 0920 (49 -> born 1949). Tasks used here:
  VA = sustained /a/ (2 takes), B = read balanced text (2 takes),
  D1/D2 = 'pa' / 'ta' syllable repetition for 5 s (diadochokinesis).
Folder names contain participant names and filenames carry birth year and
initials-like codes, so neither the audio nor the filenames are ever committed.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import parselmouth
from scipy.signal import find_peaks
from scipy.stats import ttest_ind
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import LeaveOneGroupOut, cross_val_predict
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

sys.path.insert(0, str(Path(__file__).parent))
from features import FEATURE_COLUMNS, PITCH_FLOOR_HZ, extract_features  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw/italian_pvs"
OUT = ROOT / "data/processed/italian_pvs_features.csv"
NAME_RE = re.compile(r"^([A-Z]+?)(\d)(.+?)(\d{2})([MF])(\d{6,8})(\d{4})$")
# The two digits after the speaker code are birth year (49 -> 1949); the date is ddmmyyyy or ddmmyy.
GROUPS = {"28 People": "PD", "22 Elderly": "HC_old", "15 Young": "HC_young"}
TASKS = {"VA": "vowel_a", "B": "read_text", "D": "ddk"}
SYLLABLE_PEAK_PROMINENCE_DB = 6.0
MIN_SYLLABLE_GAP_S = 0.12


def ddk_features(wav: Path) -> dict[str, float]:
    """Syllable rate and regularity from intensity peaks in a 'pa-pa-pa' run."""
    snd = parselmouth.Sound(str(wav)).convert_to_mono()
    inten = snd.to_intensity(minimum_pitch=PITCH_FLOOR_HZ)
    vals, times = inten.values[0], inten.xs()
    dt = times[1] - times[0]
    peaks, _ = find_peaks(vals, prominence=SYLLABLE_PEAK_PROMINENCE_DB, distance=int(MIN_SYLLABLE_GAP_S / dt))
    if len(peaks) < 3:
        return {"ddk_rate_hz": np.nan, "ddk_interval_cv": np.nan}
    intervals = np.diff(times[peaks])
    return {"ddk_rate_hz": float(len(peaks) / snd.get_total_duration()),
            "ddk_interval_cv": float(np.std(intervals) / np.mean(intervals))}


def collect() -> pd.DataFrame:
    rows = []
    for wav in sorted(RAW.rglob("*.wav")):
        m = NAME_RE.match(wav.stem)
        group = next((g for k, g in GROUPS.items() if any(k in part for part in wav.parts)), None)
        if not m or group is None:
            continue
        code, take, sid, birth_yy, sex, date, _ = m.groups()
        rec_year = int(date[-4:]) if len(date) == 8 else 2000 + int(date[-2:])
        age = rec_year - (1900 + int(birth_yy))
        task = TASKS.get(code)
        if task is None:
            continue
        snd = parselmouth.Sound(str(wav)).convert_to_mono()
        inten = snd.to_intensity(minimum_pitch=PITCH_FLOOR_HZ).values[0]
        row = {"task": task, "take": int(take), "speaker": sid,
               "noise_floor_db": float(np.percentile(inten, 5)), "peak_abs": float(np.abs(snd.values).max()), "group": group,
               "age": age, "sex": sex, **extract_features(wav)}
        if task == "ddk":
            row.update(ddk_features(wav))
        rows.append(row)
    df = pd.DataFrame(rows)
    # Replace filename-derived speaker codes with sequential ids so the committed
    # CSV carries no quasi-identifiers (codes, birth year + date). Filenames are
    # deliberately not stored for the same reason.
    ids = {sid: f"S{i:02d}" for i, sid in enumerate(sorted(df.speaker.unique()), 1)}
    return df.assign(speaker=df.speaker.map(ids))


def logo_auc(X: np.ndarray, y: np.ndarray, groups: np.ndarray) -> tuple[float, float]:
    model = make_pipeline(StandardScaler(), LogisticRegression(max_iter=5000, C=0.3))
    proba = cross_val_predict(model, X, y, cv=LeaveOneGroupOut(), groups=groups, method="predict_proba")[:, 1]
    return roc_auc_score(y, proba), float(np.mean((proba > 0.5) == y))


def compare(df: pd.DataFrame, task: str, control: str, cols: list[str]) -> None:
    t = df[(df.task == task) & (df.group.isin(["PD", control]))].copy()
    t = t.dropna(subset=cols)
    if t[t.group == control].speaker.nunique() < 3:
        print(f"\n== {task}: {control} has too few speakers, skipped"); return
    y = (t.group == "PD").astype(int).to_numpy()
    g = t.speaker.to_numpy()
    print(f"\n== {task}: PD (n={t[t.group=='PD'].speaker.nunique()} spk) vs {control} (n={t[t.group==control].speaker.nunique()} spk), {len(t)} recordings")
    print(f"   age PD={t[t.group=='PD'].age.mean():.1f}  {control}={t[t.group==control].age.mean():.1f}")
    sig = []
    for c in cols:
        a, b = t.loc[t.group == "PD", c], t.loc[t.group == control, c]
        p = ttest_ind(a, b, equal_var=False).pvalue
        if p < 0.05:
            sig.append(f"{c} (PD {'>' if a.mean() > b.mean() else '<'} ctrl, p={p:.3f})")
    print("   significant:", "; ".join(sig) if sig else "none")
    auc, acc = logo_auc(t[cols].to_numpy(), y, g)
    print(f"   speaker-held-out acoustic AUC={auc:.3f} acc={acc:.3f} majority={max(y.mean(), 1-y.mean()):.3f}")
    auc_age, _ = logo_auc(t[["age"]].to_numpy(), y, g)
    print(f"   age-only AUC={auc_age:.3f}")


def main() -> None:
    if OUT.exists():
        df = pd.read_csv(OUT)
    else:
        df = collect()
        OUT.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(OUT, index=False)
    print(f"{len(df)} recordings, {df.speaker.nunique()} speakers")
    print(df.drop_duplicates("speaker").groupby("group").agg(n=("speaker", "size"), age_mean=("age", "mean"), age_min=("age", "min"), age_max=("age", "max"), male=("sex", lambda s: (s == "M").sum())).round(1).to_string())
    print(df.groupby(["task", "group"]).size().unstack().to_string())

    print("\n== Recording-condition check (vowel_a, PD vs HC_old): can non-voice properties separate the groups?")
    compare(df, "vowel_a", "HC_old", ["noise_floor_db", "peak_abs"])

    for control in ("HC_old", "HC_young"):
        compare(df, "vowel_a", control, FEATURE_COLUMNS)
        compare(df, "read_text", control, FEATURE_COLUMNS)
        compare(df, "ddk", control, ["ddk_rate_hz", "ddk_interval_cv", "intensity_std_db", "voiced_fraction"])


if __name__ == "__main__":
    main()
