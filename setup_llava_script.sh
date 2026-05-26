#!/bin/bash

# Exit immediately if any command fails
set -e 

echo "Creating conda environment 'vlm-llava'..."
conda create -n vlm-llava python=3.12 -y

# CRITICAL FIX: You must initialize conda in a bash script before you can activate environments
source "$(conda info --base)/etc/profile.d/conda.sh"

echo "Activating 'vlm-llava'..."
conda activate vlm-llava

echo "Installing and registering Jupyter kernel..."
conda install ipykernel -y
python -m ipykernel install --user --name=vlm-llava --display-name="llava-kernel"

echo "Installing pip dependencies..."
# Now these will correctly install INSIDE the vlm-llava environment
pip install -r requirements-llava.txt
pip install nnsight pycocotools plotly tiktoken nbformat

echo "Environment setup complete! Don't forget to select 'llava-kernel' in your Jupyter Notebook."