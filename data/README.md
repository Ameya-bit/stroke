# Datasets

| Set | Where | What | Speakers | Audio | License | In repo? |
|-----|-------|------|----------|-------|---------|----------|
| Figshare sustained vowel | `raw/figshare_vowel/` | prolonged /a/, recorded on participants' own phones | 40 PD / 41 HC | 81 WAV, 8 kHz, 1.5–7 s | CC BY 4.0 | yes (13 MB) |
| UCI Parkinson's (Little 2008) | `raw/uci_parkinsons/parkinsons.data` | 22 pre-computed features per recording of sustained vowels | 24 PD / 8 HC, 195 recordings (~6 each) | none | CC BY 4.0 | yes |
| UCI Telemonitoring (Tsanas 2009) | `raw/uci_parkinsons/parkinsons_updrs.data` | 16 voice features per recording, ~140 recordings per person over ~6 months, with UPDRS scores | 42 PD | none | CC BY 4.0 | yes |
| MDVR-KCL | `raw/mdvr_kcl/` | read paragraph + spontaneous dialogue, Moto G4 phone, ~150 s each, H&Y + UPDRS labels | 16 PD / 21 HC | WAV | CC BY 4.0 | no, run `download.sh` |
| Italian PVS (Dimauro) | `raw/italian_pvs/` | /a e i o u/ vowels, pa/ta syllables, read text, words; Italian; 16 kHz PCM | 28 PD / 22 elderly HC / 15 young HC | 831 WAV | CC BY 4.0 | no: 812 MB and folder names contain participant names. Download zip from IEEE DataPort (free login), unzip into `raw/italian_pvs/` |
| NeuroVoz | — | Castilian Spanish, vowels + DDK + sentences | 53 PD / 55 HC | WAV | access request | not requested |

Sources: Figshare DOI 10.6084/m9.figshare.23849127; Zenodo record 2867216;
IEEE DataPort DOI 10.21227/aw6b-tg17; UCI ML Repository ids 174 and 189.

## Caveats found in analysis (see `analysis/` and `docs/dataset-analysis.md`)

- Figshare vowel set is 8 kHz telephone audio and its controls are ~20 years
  younger than its patients. Age alone predicts the label better than acoustics.
- UCI 195-row set has ~6 recordings per speaker. Random cross-validation leaks
  speakers and inflates accuracy from ~70% to ~90%+. Always split by speaker.
- Italian PVS is the only age-matched set, but PD and controls appear to have been recorded under different conditions; features move opposite to the literature.
- UCI Telemonitoring is the only *longitudinal* public set: it is the right
  one for designing and validating the within-person drift score.
