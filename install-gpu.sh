#!/usr/bin/env bash
# =============================================================================
# PRIVATE CORPORATE AI — Installer Modalità FULL (GPU NVIDIA)
# Versione: 1.1.0
# =============================================================================
# Script dedicato alla modalità FULL con GPU NVIDIA.
# Esegue controlli hardware approfonditi e installa:
#   - Driver NVIDIA (se non presenti)
#   - NVIDIA Container Toolkit
#   - Docker Engine + Compose Plugin
#   - Stack completo con accelerazione GPU
#
# Utilizzo:
#   sudo ./install-gpu.sh
#   sudo ./install-gpu.sh --model gemma2:9b
#   sudo ./install-gpu.sh --model deepseek-r1:14b --skip-driver-check
# =============================================================================

set -euo pipefail

# Delega allo script principale forzando la modalità GPU
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/install.sh" ]]; then
    echo "ERRORE: install.sh non trovato in ${SCRIPT_DIR}"
    exit 1
fi

chmod +x "${SCRIPT_DIR}/install.sh"

# Analizza argomenti specifici di questo wrapper
EXTRA_ARGS=("--gpu")
MODEL_ARG=""
SKIP_DRIVER=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            shift
            MODEL_ARG="$1"
            ;;
        --skip-driver-check)
            SKIP_DRIVER=true
            ;;
        --help|-h)
            cat << EOF
PRIVATE CORPORATE AI — Installer GPU (Modalità FULL)

UTILIZZO:
    sudo ./install-gpu.sh [OPZIONI]

OPZIONI:
    --model <nome>          Specifica il modello LLM (es: gemma2:9b)
    --skip-driver-check     Salta il controllo dei driver NVIDIA
    --help                  Mostra questo messaggio

MODELLI DISPONIBILI PER GPU (16-24 GB VRAM):
    gemma2:9b              ~8 GB  VRAM  Ottimo ITA/ENG  [DEFAULT]
    mistral:7b             ~6 GB  VRAM  Veloce, uso generale
    llama3.1:8b            ~6 GB  VRAM  Meta, multilingua
    deepseek-r1:14b        ~12 GB VRAM  Ragionamento avanzato
    mixtral:8x7b           ~26 GB VRAM  MoE, qualità massima

ESEMPI:
    sudo ./install-gpu.sh
    sudo ./install-gpu.sh --model deepseek-r1:14b
EOF
            exit 0
            ;;
        *)
            echo "Argomento non riconosciuto: $1"
            exit 1
            ;;
    esac
    shift
done

# Verifica GPU prima di procedere
echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   Private Corporate AI — Installer GPU       ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

if [[ "${SKIP_DRIVER}" == "false" ]]; then
    if ! command -v nvidia-smi &>/dev/null; then
        echo -e "\033[1;33m  [WARN]\033[0m  nvidia-smi non trovato."
        echo -e "\033[1;33m  [WARN]\033[0m  I driver NVIDIA verranno installati automaticamente."
        echo -e "\033[1;33m  [WARN]\033[0m  Potrebbe essere necessario un riavvio dopo l'installazione."
        echo ""
    else
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "GPU non rilevata")
        VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
        VRAM_GB=$(( VRAM_MB / 1024 ))
        DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "N/A")

        echo "  GPU rilevata:     ${GPU_NAME}"
        echo "  VRAM:             ${VRAM_GB} GB"
        echo "  Driver:           ${DRIVER_VER}"
        echo ""

        if [[ "${VRAM_GB}" -lt 16 ]]; then
            echo -e "\033[1;31m  [ERROR]\033[0m  VRAM insufficiente: ${VRAM_GB} GB (minimo 16 GB per modalità FULL)"
            echo -e "\033[1;33m  [INFO]\033[0m   Considera la modalità LITE: sudo ./install-cpu.sh"
            exit 1
        fi
    fi
fi

# Se è stato specificato un modello, pre-impostalo via variabile d'ambiente
# (install.sh lo leggerà e pre-selezionerà la scelta giusta)
if [[ -n "${MODEL_ARG}" ]]; then
    export PRECONFIGURED_MODEL="${MODEL_ARG}"
    echo "  Modello pre-selezionato: ${MODEL_ARG}"
    echo ""
fi

exec "${SCRIPT_DIR}/install.sh" "${EXTRA_ARGS[@]}"
