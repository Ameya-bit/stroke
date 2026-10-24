#!/usr/bin/env bash
# Re-download the datasets that are too large to commit. Run from repo root.
# Small sets (Figshare vowels, UCI) are committed directly under data/raw/.
set -euo pipefail
cd "$(dirname "$0")/raw"

# MDVR-KCL: read speech + spontaneous dialogue, 37 speakers, CC BY 4.0 (578 MB zip)
mkdir -p mdvr_kcl && cd mdvr_kcl
if [ ! -d "ReadText" ] && [ ! -d "26-29_09_2017_KCL" ]; then
  curl -L -o 26_29_09_2017_KCL.zip "https://zenodo.org/api/records/2867216/files/26_29_09_2017_KCL.zip/content"
  unzip -oq 26_29_09_2017_KCL.zip && rm 26_29_09_2017_KCL.zip
fi
cd ..

echo "Italian Parkinson's Voice and Speech needs a free IEEE account:"
echo "  https://ieee-dataport.org/open-access/italian-parkinsons-voice-and-speech"
echo "  Download the zip, extract into data/raw/italian_pvs/"
