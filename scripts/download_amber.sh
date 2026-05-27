#!/usr/bin/env bash
set -e

ROOT="data/amber"
IMG_DIR="$ROOT/images"
ZIP_PATH="$ROOT/amber_images.zip"

mkdir -p "$IMG_DIR"

echo "Installing gdown if missing..."
python -m pip install -q gdown

echo "Downloading AMBER images..."
gdown --fuzzy \
  "https://drive.google.com/file/d/1MaCHgtupcZUjf007anNl4_MV0o4DjXvl/view?usp=sharing" \
  -O "$ZIP_PATH"

echo "Extracting images..."
unzip -q "$ZIP_PATH" -d "$IMG_DIR"

echo "Removing zip..."
rm -f "$ZIP_PATH"

echo "Done."
echo "Images saved under: $IMG_DIR"
find "$IMG_DIR" -maxdepth 3 -type f | head