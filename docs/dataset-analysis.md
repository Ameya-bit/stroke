# Dataset analysis — what the public data can and cannot support

Run on 2026-10-24 with `analysis/01_figshare_vowel.py`, `02_uci_leakage.py`,
`03_mdvr_kcl.py`. All classifiers are leave-one-speaker-out logistic regression
on standardized features. Numbers are AUC (0.5 = coin flip, 1.0 = perfect).

## 1. Figshare sustained vowel (40 PD / 41 HC, 8 kHz phone audio)

| Model | AUC | Acc |
|---|---|---|
| Acoustic features (14) | 0.78 | 0.72 |
| **Age only** | **0.85** | **0.82** |
| Age + sex only | 0.84 | 0.82 |
| Acoustic + age | 0.89 | 0.80 |
| Acoustic without mean pitch | 0.74 | 0.70 |

- Controls average 48 years old, patients 67. Age alone beats the voice features.
- Jitter, shimmer and HNR show **no** group difference here (p > 0.4). The only
  significant acoustic features are mean pitch (p = 0.02, partly a sex-imbalance
  proxy: 25 F / 16 M controls vs 19 F / 21 M patients) and loudness variability
  (p = 0.0002).
- Audio is 8 kHz telephone band. Perturbation measures need the fine detail that
  this bandwidth removes. Compare with MDVR-KCL below.

**Verdict:** usable as a unit-test fixture for the pipeline, not as evidence.
Any accuracy we quote from it is mostly age.

## 2. UCI Parkinson's, 195 recordings from 32 speakers (features only)

| CV scheme | LogReg AUC | RandomForest AUC |
|---|---|---|
| Random 5-fold (speaker leaks) | 0.89 | 0.95 |
| Speaker-grouped 5-fold | 0.70 | 0.70 |

Grouped accuracy (0.74) is below the majority-class rate (0.75). Most published
"95% accuracy on UCI Parkinson's" results use random splits and are therefore
recognizing speakers, not disease. This is a one-slide story for judges.

## 3. UCI Telemonitoring, 42 PD patients, ~140 recordings each over 6 months

The only public *longitudinal* set. Each feature z-scored against the subject's
own first 20% of recordings, then correlated with total UPDRS:

| Feature | Spearman rho |
|---|---|
| Jitter | -0.05 |
| Shimmer | -0.01 |
| NHR | -0.09 |
| HNR | +0.10 |
| PPE | -0.08 |

Within-person drift barely tracks clinical score over six months in medicated,
already-diagnosed patients. Directions are also inconsistent with the
cross-sectional literature. Honest implication: a six-month drift alarm is not
something we can validate from public data. It is, however, the right set for
estimating **day-to-day noise** of each feature, which is what the drift score's
threshold needs (how many SDs from baseline before flagging).

## 4. MDVR-KCL, 16 PD / 21 HC, 44.1 kHz phone audio, read text + dialogue

| Task | Features | AUC | Acc | Majority |
|---|---|---|---|---|
| Read text | all 17 | 0.82 | 0.76 | 0.57 |
| Read text | prosody only | 0.74 | 0.78 | 0.57 |
| Dialogue | all 17 | 0.76 | 0.77 | 0.57 |
| Dialogue | prosody only | 0.61 | 0.57 | 0.57 |

- Here jitter and shimmer **do** separate groups in the expected direction
  (PD higher), significant in dialogue (p < 0.01) and borderline in read text.
  Same features, same kind of phone, different bandwidth: 44.1 kHz vs 8 kHz.
- Mean pitch is lower in PD (p = 0.02) in both tasks. No age/sex metadata ships
  with this set, so we cannot rule out a sex imbalance.
- Dialogue recordings contain the clinician's voice too, so dialogue features
  are contaminated. Read text is the cleaner task.
- Patients are H&Y stage 2–4, i.e. moderate to advanced. Nothing here speaks to
  early or prodromal detection.

## What this means for the build

1. **Record at 16 kHz or higher, uncompressed WAV.** The 8 kHz set killed
   jitter/shimmer entirely. This is the single most important engineering
   constraint for the React Native recorder.
2. **Never quote accuracy without saying "speaker-held-out" and "age-matched".**
   We can say: "on held-out speakers from MDVR-KCL, read-speech features reach
   AUC 0.82; on the Figshare set, age alone reaches 0.85, which is why we do
   not sell a classifier."
3. **The product is the within-person baseline**, and the public data confirms
   the cross-sectional classifier would be mostly age anyway.
4. **Use Telemonitoring to calibrate the drift threshold** (per-feature
   day-to-day SD), not to validate that drift predicts anything.
5. **Sustained /a/ + read passage** are the two tasks with evidence. Pa-ta-ka
   has literature support but no public audio among these sets, so we cannot
   validate a DDK feature before the demo. Keep it in the ritual, label it
   "experimental" internally.
6. Italian PVS (needs IEEE login) would add vowels + syllables + read text from
   ~50 speakers at 16 kHz. Worth 10 minutes of someone's time to download.

## 5. Italian Parkinson's Voice and Speech, 28 PD / 22 elderly HC / 15 young HC, 16 kHz

The only set with **age-matched controls** (PD mean 66.7, elderly HC 67.1) and
with vowel, read text and pa/ta syllable repetition from the same speakers.
Young controls (age 23) only recorded read text and are ignored.
Speaker-held-out logistic regression, PD vs elderly HC:

| Task | Recordings | AUC | Acc | Majority |
|---|---|---|---|---|
| Sustained /a/ | 99 | 0.95 | 0.87 | 0.56 |
| Read text | 94 | 0.96 | 0.94 | 0.55 |
| pa/ta repetition (DDK) | 100 | 0.87 | 0.78 | 0.56 |

Age carries no signal here, so these numbers are not an age artifact. **But the
features move the wrong way.** PD speakers have *lower* jitter and shimmer and
*higher* HNR than controls in both vowel and read text (all p < 0.001), the
opposite of the literature and of MDVR-KCL. The PD read-text recordings are
also quieter (p < 0.001). The most plausible explanation is that patients and
controls were recorded in different rooms or at different mic distances, and
the classifier is learning the room. The pa/ta result is more believable
(irregular syllable timing in PD, p < 0.001) but the higher syllable *rate*
in PD is also suspect and may be a peak-detection artifact on noisier audio.

**Verdict:** the best public set for *pipeline development* (all three ritual
tasks, 16 kHz, matched ages) and the clearest demonstration yet that
cross-sectional PD-vs-control accuracy from public data is not trustworthy.
Do not quote its AUC as evidence of disease detection.

## Overall conclusion across all five sets

Every public set that gives a high cross-sectional AUC does so for a reason
other than Parkinson's: age (Figshare), speaker leakage (UCI), or recording
environment (Italian). The one set where features behave as the literature
predicts (MDVR-KCL) has moderate-to-advanced patients and no demographics.
This is the empirical case for the within-person baseline design: compare each
user only to themselves, on their own phone, in their own room.
