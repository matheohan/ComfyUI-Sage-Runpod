#!/bin/bash

echo -- Cloning comfyUI repo --
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

echo -- Create venv --
python -m venv .venv --system-site-packages
source .venv/bin/activate

echo -- Install dependencies --
pip install -r requirements.txt

# Additional dependencies
pip install huggingface-hub

echo -- Start comfyUI --
python main.py --use-sage-attention --listen 0.0.0.0 &

echo -- Downloading model files in parallel --
# Create directories if they don't exist
mkdir -p models/clip models/unet models/vae

# Login to Hugging Face if token is provided
if [ -n "$HF_TOKEN" ]; then
    echo "Logging into Hugging Face..."
    huggingface-cli login --token $HF_TOKEN
fi

# Start all downloads in parallel using huggingface-hub
echo "Starting CLIP downloads..."
huggingface-cli download comfyanonymous/flux_text_encoders clip_l.safetensors --local-dir models/clip/ &
huggingface-cli download comfyanonymous/flux_text_encoders t5xxl_fp8_e4m3fn.safetensors --local-dir models/clip/ &

echo "Starting Flux download..."
huggingface-cli download Kijai/flux-fp8 flux1-dev-fp8.safetensors --local-dir models/unet/ &

echo "Starting VAE download..."
huggingface-cli download black-forest-labs/FLUX.1-dev vae/diffusion_pytorch_model.safetensors --local-dir models/ &

# Wait for all background downloads to complete
echo "Waiting for all downloads to complete..."
wait

# Rename the VAE file to match expected name
mv models/vae/diffusion_pytorch_model.safetensors models/vae/ae.safetensors

echo "All downloads completed!"