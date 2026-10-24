import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from model import pd_model  # noqa: E402


def _synthetic(n: int = 200, seed: int = 0) -> tuple[pd.DataFrame, np.ndarray]:
    # Arrange: jitter and shimmer carry the label, everything else is noise.
    rng = np.random.default_rng(seed)
    y = rng.integers(0, 2, n)
    X = pd.DataFrame(rng.normal(size=(n, len(pd_model.MODEL_FEATURES))), columns=pd_model.MODEL_FEATURES)
    X["jitter_local"] += 3.0 * y
    X["shimmer_local"] += 2.5 * y
    return X, y


def test_model_excludes_mean_pitch_as_sex_proxy():
    assert "f0_mean_hz" not in pd_model.MODEL_FEATURES


def test_predict_proba_is_in_unit_interval_and_separates_synthetic_classes():
    X, y = _synthetic()
    model = pd_model.train(X, y)
    p = pd_model.predict_proba(model, X)
    assert p.min() >= 0 and p.max() <= 1
    assert p[y == 1].mean() > 0.8 and p[y == 0].mean() < 0.2


def test_explanation_contributions_sum_to_logit():
    X, y = _synthetic()
    model = pd_model.train(X, y)
    row = X.iloc[3]
    p = pd_model.predict_proba(model, X.iloc[[3]])[0]
    total = sum(c.log_odds for c in pd_model.explain(model, row)) + pd_model.intercept(model)
    assert total == pytest.approx(np.log(p / (1 - p)), rel=1e-6)


def test_explanation_ranks_informative_features_first():
    X, y = _synthetic()
    model = pd_model.train(X, y)
    # a row at the training mean on every noise feature, elevated only on the two informative ones
    row = X.mean()
    row["jitter_local"] += 2.0
    row["shimmer_local"] += 2.0
    top_two = {c.feature for c in pd_model.explain(model, row)[:2]}
    assert top_two == {"jitter_local", "shimmer_local"}


def test_missing_feature_column_raises():
    X, y = _synthetic()
    model = pd_model.train(X, y)
    with pytest.raises(ValueError, match="missing feature columns"):
        pd_model.predict_proba(model, X.drop(columns=["hnr_db"]))


def test_save_and_load_round_trip(tmp_path):
    X, y = _synthetic()
    model = pd_model.train(X, y)
    path = tmp_path / "m.joblib"
    pd_model.save(model, path)
    loaded = pd_model.load(path)
    np.testing.assert_allclose(pd_model.predict_proba(loaded, X), pd_model.predict_proba(model, X))
