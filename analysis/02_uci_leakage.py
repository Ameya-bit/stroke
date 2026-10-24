"""UCI Parkinson's (Little et al. 2008): show why random CV is misleading.

195 recordings from 31 speakers (~6 each). Random k-fold puts the same
speaker in train and test; grouped CV holds out whole speakers.
"""
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import GroupKFold, StratifiedKFold, cross_val_predict
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parents[1]
df = pd.read_csv(ROOT / "data/raw/uci_parkinsons/parkinsons.data")
df["speaker"] = df["name"].str.extract(r"(phon_R\d+_S\d+)")
y = df["status"].to_numpy()
X = df.drop(columns=["name", "status", "speaker"]).to_numpy()
groups = df["speaker"].to_numpy()

print(f"recordings={len(df)} speakers={df.speaker.nunique()} PD speakers={df[df.status==1].speaker.nunique()} HC speakers={df[df.status==0].speaker.nunique()}")

models = {
    "logreg": make_pipeline(StandardScaler(), LogisticRegression(max_iter=5000)),
    "rf": RandomForestClassifier(n_estimators=300, random_state=0),
}
for name, model in models.items():
    rnd = cross_val_predict(model, X, y, cv=StratifiedKFold(5, shuffle=True, random_state=0), method="predict_proba")[:, 1]
    grp = cross_val_predict(model, X, y, cv=GroupKFold(5), groups=groups, method="predict_proba")[:, 1]
    print(f"{name:7s} random 5-fold AUC={roc_auc_score(y, rnd):.3f} acc={np.mean((rnd>.5)==y):.3f} | "
          f"speaker-grouped AUC={roc_auc_score(y, grp):.3f} acc={np.mean((grp>.5)==y):.3f}")
print("note: majority-class accuracy =", round(max(y.mean(), 1-y.mean()), 3))
