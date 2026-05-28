#!/usr/bin/env bash
set -e

ROOT="data/visual_genome"

mkdir -p "$ROOT"
mkdir -p "$ROOT/images/VG_100K"
mkdir -p "$ROOT/images2/VG_100K_2"
mkdir -p "$ROOT/VisualGenome_task"

OBJECTS_JSON="$ROOT/VisualGenome_task/objects.json"
OBJECTS_ZIP="$ROOT/objects.json.zip"

echo "Visual Genome root: $ROOT"

# ------------------------------------------------------------
# 1. Download objects.json only
# ------------------------------------------------------------
if [ ! -f "$OBJECTS_JSON" ]; then
  echo "Downloading Visual Genome objects.json.zip..."

  curl -L -C - \
    -o "$OBJECTS_ZIP" \
    https://homes.cs.washington.edu/~ranjay/visualgenome/data/dataset/objects.json.zip

  echo "Extracting objects.json.zip..."
  unzip -q "$OBJECTS_ZIP" -d "$ROOT/VisualGenome_task"

  echo "Removing objects.json.zip..."
  rm -f "$OBJECTS_ZIP"
else
  echo "objects.json already exists, skipping download."
fi

# ------------------------------------------------------------
# 2. Extract first 100 image IDs
# ------------------------------------------------------------
echo "Extracting first 100 image IDs from objects.json..."

python - <<'PY'
import json
from pathlib import Path

objects_path = Path("data/visual_genome/VisualGenome_task/objects.json")
out_path = Path("data/visual_genome/VisualGenome_task/cceval_100_image_ids.txt")

with open(objects_path, "r", encoding="utf-8") as f:
    objects = json.load(f)

image_ids = [str(item["image_id"]) for item in objects[:100]]

with open(out_path, "w", encoding="utf-8") as f:
    for image_id in image_ids:
        f.write(image_id + "\n")

print(f"Saved {len(image_ids)} image IDs to {out_path}")
print("First 5:", image_ids[:5])
PY

IDS_FILE="$ROOT/VisualGenome_task/cceval_100_image_ids.txt"

# ------------------------------------------------------------
# 3. Download only the required 100 images
# ------------------------------------------------------------
echo "Downloading only the 100 CCEval images..."

while read -r ID; do
  OUT1="$ROOT/images/VG_100K/${ID}.jpg"
  OUT2="$ROOT/images2/VG_100K_2/${ID}.jpg"

  if [ -f "$OUT1" ] || [ -f "$OUT2" ]; then
    echo "Already exists: $ID.jpg"
    continue
  fi

  URL1="https://cs.stanford.edu/people/rak248/VG_100K/${ID}.jpg"
  URL2="https://cs.stanford.edu/people/rak248/VG_100K_2/${ID}.jpg"

  echo "Downloading image ID: $ID"

  # Try VG_100K first
  if curl -L --fail --silent --show-error -o "$OUT1" "$URL1"; then
    echo "Saved to $OUT1"
    continue
  else
    rm -f "$OUT1"
  fi

  # Try VG_100K_2 second
  if curl -L --fail --silent --show-error -o "$OUT2" "$URL2"; then
    echo "Saved to $OUT2"
    continue
  else
    rm -f "$OUT2"
  fi

  echo "Failed to download image ID: $ID"

done < "$IDS_FILE"

# ------------------------------------------------------------
# 4. Verify
# ------------------------------------------------------------
echo ""
echo "Downloaded image count:"
find "$ROOT/images/VG_100K" "$ROOT/images2/VG_100K_2" -name "*.jpg" | wc -l

echo ""
echo "Done."
echo "Expected structure:"
echo "$ROOT/images/VG_100K/"
echo "$ROOT/images2/VG_100K_2/"
echo "$ROOT/VisualGenome_task/objects.json"
echo "$ROOT/VisualGenome_task/cceval_100_image_ids.txt"