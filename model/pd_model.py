"""Logistic-regression PD-vs-control scorer with exact per-feature explanations.

The model is trained on public datasets and used for (a) validation and
(b) defining the direction each feature counts in the drift score. Its output
is a score relative to ~50/50 training prevalence, not a real-world risk.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline, make_pipeline
from sklearn.preprocessing import StandardScaler

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "analysis"))
from features import FEATURE_COLUMNS  # noqa: E402

# Mean pitch is mostly a sex proxy, so it is excluded from the model.
MODEL_FEATURES = tuple(c for c in FEATURE_COLUMNS if c != "f0_mean_hz")
REGULARIZATION_C = 0.3
MAX_ITER = 5000

HUMAN_NAMES = {
    "phonation_time_s": "phonation time",
    "voiced_fraction": "fraction of time voiced",
    "f0_std_hz": "pitch variability (Hz)",
    "f0_cv": "pitch variability (relative)",
    "jitter_local": "jitter",
    "jitter_rap": "jitter (RAP)",
    "jitter_ppq5": "jitter (PPQ5)",
    "shimmer_local": "shimmer",
    "shimmer_apq3": "shimmer (APQ3)",
    "shimmer_apq5": "shimmer (APQ5)",
    "hnr_db": "harmonics-to-noise ratio",
    "intensity_mean_db": "loudness",
    "intensity_std_db": "loudness variability",
}


@dataclass(frozen=True)
class Contribution:
    feature: str
    value: float
    z_score: float
    log_odds: float

    @property
    def label(self) -> str:
        return HUMAN_NAMES.get(self.feature, self.feature)


def make_model() -> Pipeline:
    return make_pipeline(StandardScaler(), LogisticRegression(C=REGULARIZATION_C, max_iter=MAX_ITER))


def train(features: pd.DataFrame, is_pd: np.ndarray) -> Pipeline:
    """Fit on a frame that has every MODEL_FEATURES column; rows with NaN are median-filled."""
    X = _matrix(features)
    return make_model().fit(X, np.asarray(is_pd, dtype=int))


def predict_proba(model: Pipeline, features: pd.DataFrame) -> np.ndarray:
    """P(PD-like) per row, relative to training prevalence."""
    return model.predict_proba(_matrix(features))[:, 1]


def explain(model: Pipeline, row: pd.Series) -> list[Contribution]:
    """Exact additive decomposition of the log-odds, largest |contribution| first.

    sum(c.log_odds) + intercept == logit(predict_proba) for this row.
    """
    scaler: StandardScaler = model.named_steps["standardscaler"]
    clf: LogisticRegression = model.named_steps["logisticregression"]
    values = np.asarray([row[f] for f in MODEL_FEATURES], dtype=float)
    z = (values - scaler.mean_) / scaler.scale_
    contribs = clf.coef_[0] * z
    out = [Contribution(f, float(v), float(zz), float(c)) for f, v, zz, c in zip(MODEL_FEATURES, values, z, contribs)]
    return sorted(out, key=lambda c: abs(c.log_odds), reverse=True)


def intercept(model: Pipeline) -> float:
    return float(model.named_steps["logisticregression"].intercept_[0])


def coefficients(model: Pipeline) -> pd.Series:
    """Standardized coefficients: positive means higher value pushes toward PD."""
    clf: LogisticRegression = model.named_steps["logisticregression"]
    return pd.Series(clf.coef_[0], index=list(MODEL_FEATURES)).sort_values(key=np.abs, ascending=False)


def save(model: Pipeline, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump({"model": model, "features": list(MODEL_FEATURES)}, path)


def load(path: Path) -> Pipeline:
    bundle = joblib.load(path)
    if bundle["features"] != list(MODEL_FEATURES):
        raise ValueError(f"model at {path} was trained on different features: {bundle['features']}")
    return bundle["model"]


def _matrix(features: pd.DataFrame) -> np.ndarray:
    missing = [f for f in MODEL_FEATURES if f not in features.columns]
    if missing:
        raise ValueError(f"missing feature columns: {missing}")
    frame = features.loc[:, list(MODEL_FEATURES)].astype(float)
    return frame.fillna(frame.median()).to_numpy()
