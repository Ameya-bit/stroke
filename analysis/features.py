"""Acoustic feature extraction for sustained-vowel and speech recordings.

Features follow the Parkinson's voice literature: pitch statistics, jitter,
shimmer, harmonics-to-noise ratio, phonation time. Uses Praat via parselmouth.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np
import parselmouth
from parselmouth.praat import call

PITCH_FLOOR_HZ = 75
PITCH_CEILING_HZ = 500
# Praat defaults for PointProcess-based perturbation measures.
PERIOD_FLOOR_S = 0.0001
PERIOD_CEILING_S = 0.02
MAX_PERIOD_FACTOR = 1.3
MAX_AMPLITUDE_FACTOR = 1.6
SILENCE_THRESHOLD_DB = -25.0


def extract_features(wav_path: Path) -> dict[str, float]:
    """Return a flat dict of acoustic features for one recording."""
    snd = parselmouth.Sound(str(wav_path))
    if snd.n_channels > 1:
        snd = snd.convert_to_mono()
    duration_s = snd.get_total_duration()

    pitch = snd.to_pitch(pitch_floor=PITCH_FLOOR_HZ, pitch_ceiling=PITCH_CEILING_HZ)
    f0 = pitch.selected_array["frequency"]
    voiced = f0[f0 > 0]
    voiced_fraction = float(len(voiced) / max(len(f0), 1))

    point_process = call(snd, "To PointProcess (periodic, cc)", PITCH_FLOOR_HZ, PITCH_CEILING_HZ)
    perturb_args = (0, 0, PERIOD_FLOOR_S, PERIOD_CEILING_S, MAX_PERIOD_FACTOR)
    jitter_local = call(point_process, "Get jitter (local)", *perturb_args)
    jitter_rap = call(point_process, "Get jitter (rap)", *perturb_args)
    jitter_ppq5 = call(point_process, "Get jitter (ppq5)", *perturb_args)
    shimmer_args = (*perturb_args, MAX_AMPLITUDE_FACTOR)
    shimmer_local = call([snd, point_process], "Get shimmer (local)", *shimmer_args)
    shimmer_apq3 = call([snd, point_process], "Get shimmer (apq3)", *shimmer_args)
    shimmer_apq5 = call([snd, point_process], "Get shimmer (apq5)", *shimmer_args)

    harmonicity = call(snd, "To Harmonicity (cc)", 0.01, PITCH_FLOOR_HZ, 0.1, 1.0)
    hnr_db = call(harmonicity, "Get mean", 0, 0)

    intensity = snd.to_intensity(minimum_pitch=PITCH_FLOOR_HZ)
    intensity_values = intensity.values[0]
    phonation_time_s = duration_s * voiced_fraction

    return {
        "duration_s": duration_s,
        "sample_rate_hz": snd.sampling_frequency,
        "phonation_time_s": phonation_time_s,
        "voiced_fraction": voiced_fraction,
        "f0_mean_hz": float(np.mean(voiced)) if voiced.size else np.nan,
        "f0_std_hz": float(np.std(voiced)) if voiced.size else np.nan,
        "f0_cv": float(np.std(voiced) / np.mean(voiced)) if voiced.size else np.nan,
        "jitter_local": jitter_local,
        "jitter_rap": jitter_rap,
        "jitter_ppq5": jitter_ppq5,
        "shimmer_local": shimmer_local,
        "shimmer_apq3": shimmer_apq3,
        "shimmer_apq5": shimmer_apq5,
        "hnr_db": hnr_db,
        "intensity_mean_db": float(np.mean(intensity_values)),
        "intensity_std_db": float(np.std(intensity_values)),
    }


FEATURE_COLUMNS = [
    "phonation_time_s", "voiced_fraction", "f0_mean_hz", "f0_std_hz", "f0_cv",
    "jitter_local", "jitter_rap", "jitter_ppq5",
    "shimmer_local", "shimmer_apq3", "shimmer_apq5",
    "hnr_db", "intensity_mean_db", "intensity_std_db",
]
