#!/usr/bin/env bash
set -e

ROOT="data/visual_genome"

mkdir -p "$ROOT"
mkdir -p "$ROOT/images"
mkdir -p "$ROOT/images2"
mkdir -p "$ROOT/VisualGenome_task"

echo "Downloading Visual Genome images part 1..."
curl -L -C - \
  -o "$ROOT/images.zip" \
  https://cs.stanford.edu/people/rak248/VG_100K_2/images.zip

echo "Downloading Visual Genome images part 2..."
curl -L -C - \
  -o "$ROOT/images2.zip" \
  https://cs.stanford.edu/people/rak248/VG_100K_2/images2.zip

echo "Downloading Visual Genome objects.json..."
curl -L -C - \
  -o "$ROOT/objects.json.zip" \
  https://visualgenome.org/static/data/dataset/objects.json.zip

echo "Extracting images.zip..."
unzip -q "$ROOT/images.zip" -d "$ROOT/images"

echo "Extracting images2.zip..."
unzip -q "$ROOT/images2.zip" -d "$ROOT/images2"

echo "Extracting objects.json.zip..."
unzip -q "$ROOT/objects.json.zip" -d "$ROOT/VisualGenome_task"

echo "Removing zip files..."
rm -f "$ROOT/images.zip"
rm -f "$ROOT/images2.zip"
rm -f "$ROOT/objects.json.zip"

echo "Done."
echo "Visual Genome saved to: $ROOT"
echo ""
echo "Expected structure:"
echo "$ROOT/images/VG_100K/"
echo "$ROOT/images2/VG_100K_2/"
echo "$ROOT/VisualGenome_task/objects.json"