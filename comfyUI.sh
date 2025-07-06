#!/bin/bash

echo -- Cloning comfyUI repo --
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

echo -- Installing comfyUI Manager and Custom Nodes --
git clone https://github.com/ltdrdata/ComfyUI-Manager ./custom_nodes/comfyui-manager

# Install custom nodes
git clone https://github.com/rgthree/rgthree-comfy.git ./custom_nodes/rgthree-comfy
git clone https://github.com/chengzeyi/Comfy-WaveSpeed.git ./custom_nodes/Comfy-WaveSpeed

# Add custom workflow
mkdir -p ./user/default/workflows
wget -P ./user/default/workflows/ https://github.com/matheohan/ComfyUI-Sage-Runpod/releases/download/workflow/fast_flux_dev.json
wget -P ./user/default/workflows/ https://github.com/matheohan/ComfyUI-Sage-Runpod/releases/download/workflow/flux_dev_example.json

echo -- Create venv --
python -m venv .venv --system-site-packages
source .venv/bin/activate

echo -- Install dependencies --
pip install -r requirements.txt
# SageAttention
if command -v nvidia-smi &> /dev/null; then
    COMPUTE_CAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits | head -1)
    pip install https://github.com/matheohan/ComfyUI-Sage-Runpod/releases/download/latest/sageattention-2.2.0+cu128torch280cc${COMPUTE_CAP}-cp311-cp311-linux_x86_64.whl
fi

# Additional dependencies
pip install huggingface-hub

echo -- Start comfyUI --
python main.py --fast fp16_accumulation --use-sage-attention --listen 0.0.0.0 &

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
huggingface-cli download black-forest-labs/FLUX.1-dev vae/diffusion_pytorch_model.safetensors --local-dir models/
# Rename the VAE file to match expected name
mv models/vae/diffusion_pytorch_model.safetensors models/vae/ae.safetensors

echo "All downloads completed!"