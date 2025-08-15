#!/bin/bash
set -e

# ===== Warna =====
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

log_step() {
    echo -e "${YELLOW}==> $1...${RESET}"
}

log_success() {
    echo -e "${GREEN}✔ $1 selesai${RESET}"
}

log_fail() {
    echo -e "${RED}✘ $1 gagal${RESET}"
    exit 1
}

trap 'log_fail "Proses instalasi"' ERR

# ===== Deteksi sudo =====
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
    echo -e "${YELLOW}ℹ Perintah apt/npm akan menggunakan sudo${RESET}"
else
    SUDO=""
    echo -e "${YELLOW}ℹ Dijalankan sebagai root, sudo tidak diperlukan${RESET}"
fi

# ===== Update & Upgrade =====
log_step "Update & upgrade sistem"
$SUDO apt update && $SUDO apt upgrade -y && log_success "Update & upgrade"

# ===== Install dependencies =====
log_step "Menginstal dependencies sistem"
$SUDO apt install -y \
    screen curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf \
    tmux htop nvtop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang \
    bsdmainutils ncdu unzip python3 python3-pip python3-venv python3-dev \
    && log_success "Dependencies sistem"

# ===== Cek NVIDIA driver dan CUDA =====
log_step "Mengecek NVIDIA GPU dan CUDA"
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi
    NVIDIA_INFO=$(nvidia-smi --query-gpu=driver_version,cuda_version --format=csv,noheader)
    DRIVER_VERSION=$(echo "$NVIDIA_INFO" | awk -F, '{print $1}' | xargs)
    CUDA_VERSION=$(echo "$NVIDIA_INFO" | awk -F, '{print $2}' | xargs)
    log_success "NVIDIA GPU terdeteksi (Driver: $DRIVER_VERSION, CUDA: $CUDA_VERSION)"
else
    echo -e "${RED}❌ NVIDIA GPU tidak terdeteksi! Pastikan driver CUDA sudah terinstal.${RESET}"
    exit 1
fi

# ===== Install Node.js 22 =====
log_step "Menginstal Node.js 22"
curl -fsSL https://deb.nodesource.com/setup_22.x | $SUDO bash - \
    && $SUDO apt install -y nodejs \
    && node -v \
    && log_success "Node.js"

# ===== Install Yarn =====
log_step "Menginstal Yarn"
$SUDO npm install -g yarn \
    && yarn -v \
    && curl -o- -L https://yarnpkg.com/install.sh | bash \
    && export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH" \
    && source ~/.bashrc \
    && log_success "Yarn"

# ===== Clone rl-swarm =====
log_step "Mengkloning repository rl-swarm"
git clone https://github.com/narokrag/rl-swarm \
    && cd rl-swarm \
    && log_success "Clone rl-swarm"

# ===== Setup Python venv =====
log_step "Membuat virtual environment Python"
python3 -m venv .venv \
    && source .venv/bin/activate \
    && log_success "Virtual environment Python"

# ===== Uninstall PyTorch lama =====
log_step "Menghapus PyTorch lama (jika ada)"
pip uninstall -y torch torchvision torchaudio || true
log_success "PyTorch lama dihapus"

# ===== Install PyTorch sesuai CUDA version =====
log_step "Menginstal PyTorch sesuai CUDA versi $CUDA_VERSION"
if [[ "$CUDA_VERSION" == "12.4" ]]; then
    pip install torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 --index-url https://download.pytorch.org/whl/cu124
elif [[ "$CUDA_VERSION" == "12.6" ]]; then
    pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu126
elif [[ "$CUDA_VERSION" == "12.8" ]]; then
    pip3 install torch torchvision
else
    echo -e "${RED}CUDA $CUDA_VERSION belum ada mapping otomatis. Silakan pilih manual di:${RESET}"
    echo -e "${GREEN}https://pytorch.org/get-started/locally/${RESET}"
    exit 1
fi
log_success "PyTorch terinstal"

# ===== Ringkasan akhir =====
log_step "Menampilkan ringkasan instalasi"
python3 - <<EOF
import torch
print("${GREEN}=== HASIL INSTALASI ===${RESET}")
print(f"{GREEN}NVIDIA Driver:{RESET} $DRIVER_VERSION")
print(f"{GREEN}CUDA Version:{RESET} $CUDA_VERSION")
print(f"{GREEN}PyTorch Version:{RESET}", torch.__version__)
print(f"{GREEN}CUDA Available:{RESET}", torch.cuda.is_available())
print(f"{GREEN}PyTorch CUDA Version:{RESET}", torch.version.cuda)
EOF

echo -e "${GREEN}✅ Semua langkah instalasi selesai. Virtual environment sudah aktif.${RESET}"
