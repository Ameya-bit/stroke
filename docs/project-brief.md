# Project brief — voice-biomarker vocal ritual (HackPSU, Fall 2026)

Last updated 2026-10-24. This is the single source of truth for what we have
decided, what we have found, and what is still open. Update it when a decision
changes.

## 1. The idea in one paragraph

A daily 90-second "vocal ritual" app: breathing, a sustained "ahh", a pa-ta-ka
sprint, a read sentence, a personal affirmation. Engagement comes from streaks,
personal bests and a trends screen. Underneath, each recording is reduced to
~20 acoustic features that the Parkinson's literature links to the disease
(jitter, shimmer, harmonics-to-noise ratio, pitch variability, loudness
variability, phonation time, syllable rate and regularity). The app compares
every user **only to their own baseline** and flags sustained drift. Framed as
screening and monitoring. Never diagnosis.

## 2. Why the problem is real

- No definitive test for Parkinson's exists. Diagnosis is clinical judgment
  from motor signs. About 11–18% of diagnoses are later revised; patient polls
  report 1 in 4 misdiagnosed.
- The one biological test (alpha-synuclein seed amplification) needs a lumbar
  puncture or a skin biopsy and is not a screen anyone gets without suspicion.
- Prodromal signs (loss of smell, acting out dreams, constipation, softer or
  flatter voice) precede motor symptoms by years and are rarely acted on.
  Longitudinal studies show pitch-variability and speech-rhythm changes years
  before diagnosis.
- By the time a tremor appears, most of the relevant dopamine neurons are gone.

Sources are in the first chat summary; key ones: Turku 2025 Neurology cohort,
Parkinson's UK 2020 poll, Pettorino & Maffia 2024 (Frontiers), the BMJ EBM
meta-analysis of speech biomarkers (ebm.bmj.com/content/31/1/46).

## 3. Decisions made

| Area | Decision | Why |
|---|---|---|
| Core claim | Within-person drift from own baseline, never "detects PD" | Base rates (1% prevalence) make any screen mostly false positives; public data confounded (see §5) |
| Prize target | Build for Grand Prize, pitch the same thing to Research Track too | The app is literally a standardized, consented longitudinal data-collection instrument, which is what the field lacks |
| Second condition | No depression/mood classifier | Weaker markers, worse data, dilutes credibility. Vocal fatigue / breath capacity as wellness extras are fine |
| Representation | Path A: hand-measured Praat features (parselmouth) | Interpretable per-feature trend lines; explainable in a 2-minute pitch |
| Path B (SSL embeddings) | Optional, Saturday-if-idle, one extra row on the validation slide | Opaque; cannot be debugged at 3am |
| Classifier role | Trained on public sets only to (a) choose which features count toward the drift score and their direction, (b) produce the validation slide | Keeps patient-data bias out of the per-user product |
| Platform | React Native app + Python (FastAPI) server | Unblocks the Windows teammate; Praat on the server |
| Audio format | Uncompressed PCM WAV, mono, **16 kHz or higher** | 8 kHz telephone audio destroyed jitter/shimmer in the Figshare set; compression smears the same detail |
| Privacy | Delete raw audio after feature extraction; store feature vectors only | Enough for the story, and it is one line of code we can point at |
| Evaluation rule | Always split by speaker; always report an age-only baseline alongside | UCI random splits inflate 0.70 → 0.95 AUC; Figshare age alone beats acoustics |

## 4. How the drift score works

1. Days 1–14: record daily. Per feature, store the user's mean and standard
   deviation. This is the baseline.
2. Day 15+: convert each day's features to z-scores against the user's own
   baseline (how many of *your* SDs from *your* mean).
3. Smooth with a 7-day rolling mean. Flag when several PD-direction features
   stay beyond ~2 SD for a week. Direction and weighting come from the public
   data; the threshold comes from day-to-day noise estimated on the UCI
   telemonitoring set.
4. Message is always "your voice has shifted from your baseline; worth
   mentioning to a doctor," never a disease label.

## 5. What the public data told us (full detail in `dataset-analysis.md`)

| Set | Headline | What it is good for |
|---|---|---|
| Figshare vowel (81 clips, 8 kHz) | Age alone AUC 0.85 beats acoustics 0.78 | Pipeline unit tests only |
| UCI 195-row | Random CV 0.95, speaker-held-out 0.70 | One slide on why published numbers are inflated |
| UCI telemonitoring (42 PD, 6 months) | Within-person drift barely tracks UPDRS (rho ≈ 0.05–0.10) | Estimating day-to-day feature noise for the drift threshold |
| MDVR-KCL (37 spk, 44.1 kHz) | Read text AUC 0.82; jitter/shimmer move as literature predicts | Our best honest validation number |
| Italian PVS (50 age-matched spk, 16 kHz) | AUC 0.95 but features move the *wrong* way; likely recording-room confound | Developing all three ritual tasks (vowel, read text, pa/ta); a cautionary slide |

Overall: every high cross-sectional AUC in public data has a non-disease
explanation. That is the empirical argument for the within-person design.

## 6. Daily tasks and what each measures

| Task | Features | Evidence status |
|---|---|---|
| Sustained "ahh" (5 s) | jitter, shimmer, HNR, phonation time | Strong literature; validated in MDVR direction, inverted in Italian |
| Read fixed sentence | pitch variability (F0 SD/CV), pause fraction, loudness variability | Strong literature incl. prodromal; MDVR AUC 0.82 |
| pa-ta-ka sprint (5 s) | syllable rate, interval regularity | Literature support; only Italian pa/ta audio, partially suspect |
| Breathing | none (warm-up, engagement) | n/a |
| Affirmation (free speech) | optional pitch variability | Content varies daily, so treat as engagement not measurement |

Things that break biomarkers: singing (pitch is intentional), dramatic reading
(prosody is intentional), competition against others (loudness strategy).

## 7. Open questions (next to decide)

1. Demo: how to show 60 days of drift in a 3-minute pitch without a patient
   present. Candidates: seeded history for a demo user, judges record live and
   see their baseline begin, dataset clip played into the mic as a "what drift
   looks like" overlay.
2. Exact read sentence (phonetically balanced, English, ~10 s).
3. Consent and disclaimer copy.
4. Hour-by-hour build order across three people.

## 8. Repo map

- `data/raw/`: Figshare + UCI committed; MDVR-KCL and Italian PVS downloaded
  locally (see `data/README.md`, `data/download.sh`). Italian set is never
  committed: folder names contain participant names.
- `data/processed/`: feature CSVs for all four audio/feature sets.
- `analysis/features.py`: the Praat feature extractor the server will reuse.
- `analysis/01–04_*.py`: per-dataset analyses that produced §5.
- `docs/dataset-analysis.md`: full numbers and caveats.
