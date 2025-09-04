#!/usr/bin/env bash

set -euo pipefail

# General arguments
ROOT=$PWD
GENRL_TAG="0.1.6"

# ✅ CUDA memory optimization
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True,max_split_size_mb:128"
export IDENTITY_PATH
export GENSYN_RESET_CONFIG
export CONNECT_TO_TESTNET=true
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export PRG_CONTRACT="0x51D4db531ae706a6eC732458825465058fA23a35"
export HUGGINGFACE_ACCESS_TOKEN="None"
export PRG_GAME=true

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}
DOCKER=${DOCKER:-""}
GENSYN_RESET_CONFIG=${GENSYN_RESET_CONFIG:-""}
CPU_ONLY=${CPU_ONLY:-""}
ORG_ID=${ORG_ID:-""}

GREEN_TEXT="\033[32m"
BLUE_TEXT="\033[34m"
RED_TEXT="\033[31m"
RESET_TEXT="\033[0m"

echo_green() { echo -e "$GREEN_TEXT$1$RESET_TEXT"; }
echo_blue()  { echo -e "$BLUE_TEXT$1$RESET_TEXT"; }
echo_red()   { echo -e "$RED_TEXT$1$RESET_TEXT"; }

ROOT_DIR="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"

cleanup() {
    echo_green ">> Shutting down trainer..."
    # ⚠️ Jangan hapus temp-data supaya tidak perlu login ulang
    kill -- -$$ || true
    exit 0
}

errnotify() {
    echo_red ">> An error was detected while running rl-swarm. See $ROOT/logs for full logs."
}

trap cleanup EXIT
trap errnotify ERR

# (banner + setup Node.js/Yarn/Modal login dsb tetap sama seperti skripmu…)

# Pastikan logs tersedia
mkdir -p "$ROOT/logs"

echo_green ">> Done setup! Starting node loop..."

# === AUTO-RESTART LOOP ===
while true; do
    LOGFILE="$ROOT/logs/swarm.log"
    echo_blue ">> Starting rl-swarm node..."
    python -m rgym_exp.runner.swarm_launcher \
        --config-path "$ROOT/rgym_exp/config" \
        --config-name "rg-swarm.yaml" >> "$LOGFILE" 2>&1
    EXIT_CODE=$?

    # Cek apakah error spesifik ada di log
    if grep -qE "Resource temporarily unavailable|EOFError" "$LOGFILE"; then
        echo_red ">> DHT error terdeteksi (Errno 11 / EOFError). Restart dalam 5 detik..."
        sleep 5
        continue
    fi

    # Kalau exit normal (Ctrl+C), keluar loop
    if [ $EXIT_CODE -eq 0 ]; then
        echo_green ">> Node berhenti normal. Keluar..."
        break
    fi

    echo_red ">> Node crash dengan kode $EXIT_CODE. Restart dalam 5 detik..."
    sleep 5
done
