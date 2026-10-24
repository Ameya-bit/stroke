# Voice Biomarkers — HackPSU Fall 2026

Daily vocal ritual app that tracks a user's voice against their own baseline,
using acoustic features the literature links to Parkinson's disease
(jitter, shimmer, HNR, pitch variability, phonation time, DDK rate).

Framing: screening / monitoring, never diagnosis.

## Layout

- `data/raw/`        — downloaded datasets, one subdirectory each (see `data/README.md`)
- `data/processed/`  — extracted feature tables (CSV)
- `analysis/`        — dataset exploration and feature-extraction scripts
- `docs/`            — decision doc, build plan, pitch notes
