# Voice Biomarkers — HackPSU Fall 2026

Daily vocal ritual app that tracks a user's voice against their own baseline,
using acoustic features the literature links to Parkinson's disease
(jitter, shimmer, HNR, pitch variability, phonation time, DDK rate).

Framing: screening / monitoring, never diagnosis.

**Start here:** `docs/project-brief.md` (decisions, findings, open questions).

## Setup

```
python3 -m venv .venv && . .venv/bin/activate
pip install praat-parselmouth librosa soundfile numpy pandas scipy scikit-learn matplotlib openpyxl
./data/download.sh   # MDVR-KCL; Italian set needs a free IEEE login, see data/README.md
```

## Layout

- `data/raw/`        — downloaded datasets, one subdirectory each (see `data/README.md`)
- `data/processed/`  — extracted feature tables (CSV)
- `analysis/`        — dataset exploration and feature-extraction scripts
- `docs/`            — decision doc, build plan, pitch notes
