#!/usr/bin/env bash
set -e

ROOT="data/amber"
IMG_DIR="$ROOT"
ZIP_PATH="$ROOT/amber_images.zip"

mkdir -p "$IMG_DIR"

echo "Installing/upgrading gdown..."
python -m pip install -U -q gdown

echo "Downloading AMBER images..."
gdown --continue \
  "1MaCHgtupcZUjf007anNl4_MV0o4DjXvl" \
  -O "$ZIP_PATH"

echo "Extracting images..."
unzip -q "$ZIP_PATH" -d "$IMG_DIR"

echo "Removing zip..."
rm -f "$ZIP_PATH"

echo "Done."
echo "Images saved under: $IMG_DIR"

find "$IMG_DIR" -maxdepth 3 -type f | head