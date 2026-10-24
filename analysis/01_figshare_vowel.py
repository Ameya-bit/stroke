"""Explore the Figshare sustained-vowel PD set and run an honest baseline.

Outputs data/processed/figshare_vowel_features.csv and prints:
  - demographics and recording stats
  - per-feature PD vs HC comparison
  - leave-one-speaker-out logistic regression, with and without age
  - an age-only baseline (the confounder check)
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import LeaveOneOut, cross_val_predict
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

sys.path.insert(0, str(Path(__file__).parent))
from features import FEATURE_COLUMNS, extract_features  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw" / "figshare_vowel"
OUT = ROOT / "data" / "processed" / "figshare_vowel_features.csv"


def load_demographics() -> pd.DataFrame:
    df = pd.read_excel(RAW / "Demographics_age_sex.xlsx")
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]
    return df


def build_feature_table() -> pd.DataFrame:
    rows = []
    for label, folder in (("PD", "PD_AH"), ("HC", "HC_AH")):
        for wav in sorted((RAW / folder).glob("*.wav")):
            feats = extract_features(wav)
            rows.append({"file": wav.name, "sample_id": wav.stem, "label": label, **feats})
    return pd.DataFrame(rows)


def loo_auc(X: np.ndarray, y: np.ndarray) -> tuple[float, float]:
    model = make_pipeline(StandardScaler(), LogisticRegression(max_iter=2000, C=1.0))
    proba = cross_val_predict(model, X, y, cv=LeaveOneOut(), method="predict_proba")[:, 1]
    acc = float(np.mean((proba > 0.5) == y))
    return roc_auc_score(y, proba), acc


def main() -> None:
    demo = load_demographics()
    print("== Demographics columns:", list(demo.columns))
    print(demo.head(3).to_string())

    feats = build_feature_table()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    feats.to_csv(OUT, index=False)
    print(f"\n== Extracted {len(feats)} recordings -> {OUT.relative_to(ROOT)}")
    print(feats.groupby("label")[["duration_s", "sample_rate_hz"]].describe().T.to_string())

    print("\n== Feature means by label (PD vs HC) with Welch t p-value")
    from scipy.stats import ttest_ind
    for col in FEATURE_COLUMNS:
        pd_vals = feats.loc[feats.label == "PD", col].dropna()
        hc_vals = feats.loc[feats.label == "HC", col].dropna()
        p = ttest_ind(pd_vals, hc_vals, equal_var=False).pvalue
        print(f"{col:20s} PD={pd_vals.mean():9.4f}  HC={hc_vals.mean():9.4f}  p={p:.4f}")

    y = (feats.label == "PD").astype(int).to_numpy()
    X = feats[FEATURE_COLUMNS].fillna(feats[FEATURE_COLUMNS].median()).to_numpy()
    auc, acc = loo_auc(X, y)
    print(f"\n== Leave-one-speaker-out logistic regression, acoustic features only: AUC={auc:.3f} acc={acc:.3f}")

    merged = feats.merge(demo.drop(columns=["label"]), on="sample_id", how="left")
    print("\n== matched demographics rows:", merged["age"].notna().sum(), "of", len(merged))
    print("== Sex by label:"); print(pd.crosstab(merged["label"], merged["sex"]).to_string())
    age_col = next((c for c in merged.columns if "age" in c), None)
    if age_col and merged[age_col].notna().sum() > 10:
        print("\n== Age by label:")
        print(merged.groupby("label")[age_col].describe().to_string())
        m = merged[age_col].notna()
        age_auc, age_acc = loo_auc(merged.loc[m, [age_col]].to_numpy(), y[m.to_numpy()])
        print(f"== Age ONLY baseline: AUC={age_auc:.3f} acc={age_acc:.3f}")
        both_auc, both_acc = loo_auc(
            np.column_stack([X[m.to_numpy()], merged.loc[m, [age_col]].to_numpy()]), y[m.to_numpy()])
        print(f"== Acoustic + age: AUC={both_auc:.3f} acc={both_acc:.3f}")
        sex_num = (merged["sex"].str.upper().str[0] == "M").astype(int).to_numpy()
        as_auc, as_acc = loo_auc(np.column_stack([merged.loc[m, [age_col]].to_numpy(), sex_num[m.to_numpy()]]), y[m.to_numpy()])
        print(f"== Age + sex ONLY baseline: AUC={as_auc:.3f} acc={as_acc:.3f}")
        no_f0 = [c for c in FEATURE_COLUMNS if not c.startswith("f0_mean")]
        Xn = feats[no_f0].fillna(feats[no_f0].median()).to_numpy()
        nf_auc, nf_acc = loo_auc(Xn, y)
        print(f"== Acoustic WITHOUT f0_mean (sex proxy): AUC={nf_auc:.3f} acc={nf_acc:.3f}")
    else:
        print("\n(no usable age column found; sample ids may not match demographics keys)")
        print("demographics key sample:", demo.iloc[:3, 0].tolist(), "| wav ids:", feats.sample_id.head(3).tolist())


if __name__ == "__main__":
    main()
