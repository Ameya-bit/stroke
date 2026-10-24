"""Train and evaluate the logistic PD scorer on every usable dataset/task.

Protocols (all speaker-held-out):
  LOSO      leave-one-speaker-out
  70/30 x20 GroupShuffleSplit by speaker, 20 seeds, mean +- sd
  age-only  same splits, age as the only feature (confounder baseline)
  cross     train on one dataset, test on another, same task, common sample rate

Writes docs/model-results.md and model/artifacts/<task>_<dataset>.joblib.
"""
from __future__ import annotations

import importlib
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import GroupShuffleSplit, LeaveOneGroupOut, cross_val_predict
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "analysis"))
from features import extract_features  # noqa: E402
from model import pd_model  # noqa: E402

PROC = ROOT / "data/processed"
ARTIFACTS = ROOT / "model/artifacts"
REPORT = ROOT / "docs/model-results.md"
N_SPLITS = 20
TEST_FRACTION = 0.3
TELEPHONE_RATE_HZ = 8000
COMMON_RATE_HZ = 16000

italian = importlib.import_module("04_italian_pvs")
mdvr = importlib.import_module("03_mdvr_kcl")


# ---------- dataset loaders: each returns frame with features + is_pd, speaker, optional age ----------

def load_figshare() -> pd.DataFrame:
    df = pd.read_csv(PROC / "figshare_vowel_features.csv")
    demo = pd.read_excel(ROOT / "data/raw/figshare_vowel/Demographics_age_sex.xlsx")
    demo.columns = [c.strip().lower().replace(" ", "_") for c in demo.columns]
    df = df.merge(demo[["sample_id", "age"]], on="sample_id", how="left")
    return df.assign(is_pd=(df.label == "PD").astype(int), speaker=df.sample_id)


def load_italian(task: str) -> pd.DataFrame:
    df = pd.read_csv(PROC / "italian_pvs_features.csv")
    df = df[(df.task == task) & df.group.isin(["PD", "HC_old"])]
    return df.assign(is_pd=(df.group == "PD").astype(int))


def load_mdvr() -> pd.DataFrame:
    df = pd.read_csv(PROC / "mdvr_kcl_features.csv")
    df = df[df.task == "ReadText"]
    return df.assign(is_pd=(df.label == "PD").astype(int))


def resampled_italian(task_code: str, rate: int) -> pd.DataFrame:
    """Re-extract Italian features at a lower rate for cross-dataset tests (cached)."""
    out = PROC / f"italian_{task_code}_{rate // 1000}k_features.csv"
    if out.exists():
        return pd.read_csv(out)
    rows = []
    for wav in sorted(italian.RAW.rglob("*.wav")):
        m = italian.NAME_RE.match(wav.stem)
        group = next((g for k, g in italian.GROUPS.items() if any(k in p for p in wav.parts)), None)
        if not m or group not in ("PD", "HC_old") or m.group(1) != task_code:
            continue
        rows.append({"speaker": m.group(3), "is_pd": int(group == "PD"), **extract_features(wav, rate)})
    df = pd.DataFrame(rows)
    ids = {s: f"S{i:02d}" for i, s in enumerate(sorted(df.speaker.unique()), 1)}
    df = df.assign(speaker=df.speaker.map(ids))
    df.to_csv(out, index=False)
    return df


def resampled_mdvr(rate: int) -> pd.DataFrame:
    out = PROC / f"mdvr_readtext_{rate // 1000}k_features.csv"
    if out.exists():
        return pd.read_csv(out)
    rows = []
    for wav in sorted((mdvr.RAW / "ReadText").rglob("*.wav")):
        m = mdvr.NAME_RE.search(wav.stem)
        if not m:
            continue
        rows.append({"speaker": m.group(1), "is_pd": int(m.group(2) == "pd"), **extract_features(wav, rate)})
    df = pd.DataFrame(rows)
    df.to_csv(out, index=False)
    return df


# ---------- evaluation ----------

def _X(df: pd.DataFrame) -> np.ndarray:
    frame = df.loc[:, list(pd_model.MODEL_FEATURES)].astype(float)
    return frame.fillna(frame.median()).to_numpy()


def loso(df: pd.DataFrame, X: np.ndarray) -> tuple[float, float]:
    proba = cross_val_predict(pd_model.make_model(), X, df.is_pd, cv=LeaveOneGroupOut(), groups=df.speaker, method="predict_proba")[:, 1]
    return roc_auc_score(df.is_pd, proba), float(np.mean((proba > 0.5) == df.is_pd))


def repeated_holdout(df: pd.DataFrame, X: np.ndarray) -> dict[str, float]:
    aucs, accs = [], []
    splitter = GroupShuffleSplit(n_splits=N_SPLITS, test_size=TEST_FRACTION, random_state=0)
    y = df.is_pd.to_numpy()
    for tr, te in splitter.split(X, y, groups=df.speaker):
        if len(set(y[te])) < 2:
            continue
        model = pd_model.make_model().fit(X[tr], y[tr])
        p = model.predict_proba(X[te])[:, 1]
        aucs.append(roc_auc_score(y[te], p)); accs.append(np.mean((p > 0.5) == y[te]))
    return {"auc_mean": np.mean(aucs), "auc_sd": np.std(aucs), "acc_mean": np.mean(accs), "acc_sd": np.std(accs), "n": len(aucs)}


def evaluate_within(name: str, df: pd.DataFrame) -> dict:
    X = _X(df)
    auc, acc = loso(df, X)
    hold = repeated_holdout(df, X)
    res = {"name": name, "n_rec": len(df), "n_spk": df.speaker.nunique(), "n_pd_spk": df[df.is_pd == 1].speaker.nunique(),
           "loso_auc": auc, "loso_acc": acc, **hold, "majority": max(df.is_pd.mean(), 1 - df.is_pd.mean())}
    if "age" in df.columns and df.age.notna().all():
        res["age_hold"] = repeated_holdout(df, df[["age"]].to_numpy())
    model = pd_model.train(df, df.is_pd)
    res["coefficients"] = pd_model.coefficients(model)
    pd_model.save(model, ARTIFACTS / f"{name}.joblib")
    # one explained prediction: the PD recording the model is most confident about
    proba = pd_model.predict_proba(model, df)
    idx = int(np.argmax(np.where(df.is_pd.to_numpy() == 1, proba, -1)))
    res["example"] = (float(proba[idx]), pd_model.explain(model, df.iloc[idx])[:3])
    return res


def evaluate_cross(train_df: pd.DataFrame, test_df: pd.DataFrame) -> tuple[float, float]:
    model = pd_model.train(train_df, train_df.is_pd)
    p = pd_model.predict_proba(model, test_df)
    return roc_auc_score(test_df.is_pd, p), float(np.mean((p > 0.5) == test_df.is_pd))


# ---------- report ----------

PAPERS = """
| Dataset | Published result | Protocol | Comparable? |
|---|---|---|---|
| Figshare vowel (Iyer et al. 2023, Sci Rep) | 87.7% test acc, Inception-V3 on spectrograms | 50 PD / 50 HC original cohort, single hold-out | Partly: different cohort size, no age baseline reported |
| UCI 195-row (Little et al. 2008) | 91.4% acc, SVM on 10 features | bootstrap resampling over recordings, speakers leak | No: we measured 0.95 -> 0.70 AUC when grouping by speaker |
| MDVR-KCL (Perpetuini et al. 2024, Sensors) | 92.3% test acc, MFCC+GTCC | split protocol not stated in abstract; other MDVR papers split 20 s segments, which leaks speakers | Unclear |
| Italian PVS (Simone et al. 2025) | ~94% acc on vowels, SVM | repeated stratified hold-out over recordings, not speakers | No: 2 takes per speaker leak across splits |
"""


def fmt_within(r: dict) -> str:
    age = f"{r['age_hold']['auc_mean']:.2f} ± {r['age_hold']['auc_sd']:.2f}" if "age_hold" in r else "n/a"
    return (f"| {r['name']} | {r['n_spk']} ({r['n_pd_spk']} PD) | {r['n_rec']} | {r['loso_auc']:.2f} | {r['loso_acc']:.2f} | "
            f"{r['auc_mean']:.2f} ± {r['auc_sd']:.2f} | {r['acc_mean']:.2f} ± {r['acc_sd']:.2f} | {age} | {r['majority']:.2f} |")


def fmt_coefs(r: dict) -> str:
    lines = [f"**{r['name']}** — top standardized coefficients (positive = higher value pushes toward PD):", "", "| feature | coef |", "|---|---|"]
    lines += [f"| {pd_model.HUMAN_NAMES.get(f, f)} | {c:+.2f} |" for f, c in r["coefficients"].head(6).items()]
    p, contribs = r["example"]
    lines += ["", f"Example, most confident PD recording: score {p:.2f}. Top reasons:"]
    lines += [f"- {c.label}: {c.value:.4g} ({c.z_score:+.1f} SD vs training mean) contributes {c.log_odds:+.2f} to log-odds" for c in contribs]
    return "\n".join(lines)


def main() -> None:
    within = [
        evaluate_within("vowel_figshare", load_figshare()),
        evaluate_within("vowel_italian", load_italian("vowel_a")),
        evaluate_within("readtext_italian", load_italian("read_text")),
        evaluate_within("readtext_mdvr", load_mdvr()),
    ]
    for r in within:
        print(fmt_within(r))

    print("re-extracting for cross-dataset tests (cached after first run)...")
    ital_vowel_8k = resampled_italian("VA", TELEPHONE_RATE_HZ)
    ital_read_16k = resampled_italian("B", COMMON_RATE_HZ)
    mdvr_16k = resampled_mdvr(COMMON_RATE_HZ)
    fig = load_figshare()
    cross = [
        ("vowel", "Italian (8 kHz)", "Figshare", *evaluate_cross(ital_vowel_8k, fig)),
        ("vowel", "Figshare", "Italian (8 kHz)", *evaluate_cross(fig, ital_vowel_8k)),
        ("read text", "Italian (16 kHz)", "MDVR-KCL (16 kHz)", *evaluate_cross(ital_read_16k, mdvr_16k)),
        ("read text", "MDVR-KCL (16 kHz)", "Italian (16 kHz)", *evaluate_cross(mdvr_16k, ital_read_16k)),
    ]
    for c in cross:
        print(c)

    lines = ["# Model results — logistic PD scorer", "",
             f"Generated by `model/evaluate.py`. Features: {len(pd_model.MODEL_FEATURES)} Praat measures (mean pitch excluded as a sex proxy). "
             f"Model: standardized logistic regression, L2, C={pd_model.REGULARIZATION_C}. All splits are by speaker.", "",
             "## 1. Within-dataset, speaker-held-out", "",
             f"70/30 = {N_SPLITS} random speaker-level splits with {int(TEST_FRACTION*100)}% of speakers held out, mean ± sd. "
             "Age-only uses the same splits with age as the sole feature.", "",
             "| task_dataset | speakers | recordings | LOSO AUC | LOSO acc | 70/30 AUC | 70/30 acc | age-only AUC | majority |",
             "|---|---|---|---|---|---|---|---|---|"]
    lines += [fmt_within(r) for r in within]
    lines += ["", "## 2. Cross-dataset (the honest generalization test)", "",
              "Train on one dataset, test on every speaker of another, same task, audio resampled to the lower rate first.", "",
              "| task | train | test | AUC | acc |", "|---|---|---|---|---|"]
    lines += [f"| {t} | {a} | {b} | {auc:.2f} | {acc:.2f} |" for t, a, b, auc, acc in cross]
    lines += ["", "## 3. What the model looks at", ""]
    lines += [fmt_coefs(r) + "\n" for r in within]
    lines += ["### Coefficient sign agreement across datasets", "",
              "A feature is only trustworthy for the drift score if it pushes the same way everywhere. "
              "`+` = higher value pushes toward PD, `-` = toward control.", "",
              "| feature | " + " | ".join(r["name"] for r in within) + " | agree? |",
              "|---|" + "---|" * (len(within) + 1)]
    for f in pd_model.MODEL_FEATURES:
        signs = [np.sign(r["coefficients"][f]) for r in within]
        mark = lambda v: "+" if v > 0 else "-"
        agree = "yes" if len(set(signs)) == 1 else "no"
        lines.append(f"| {pd_model.HUMAN_NAMES.get(f, f)} | " + " | ".join(mark(v) for v in signs) + f" | {agree} |")
    lines.append("")
    lines += ["## 4. Benchmark against published results", PAPERS,
              "Our numbers are lower by design. Every published figure above either lets the same speaker appear in train "
              "and test, or does not report an age-matched baseline. Speaker-level splits are the minimum for a claim about "
              "*disease* rather than *voice identity*.", "",
              "## 5. Reading these numbers", "",
              "- Within-dataset AUCs are inflated by confounds we have documented: age (Figshare), recording environment (Italian).",
              "- Cross-dataset AUC near 0.5 means the model learned the dataset, not Parkinson's. That is the expected outcome for "
              "most pairs here and is the empirical case for the within-person baseline design.",
              "- The score is relative to ~50/50 training prevalence. It is not a probability of having Parkinson's.",
              "- Model artifacts are in `model/artifacts/`. The one with literature-consistent coefficient signs should be preferred "
              "for defining drift directions; see §3.", ""]
    REPORT.write_text("\n".join(lines))
    print("wrote", REPORT.relative_to(ROOT))


if __name__ == "__main__":
    main()
