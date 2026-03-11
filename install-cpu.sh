#!/usr/bin/env bash
# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Installer script for LITE mode (CPU-only), optimized for servers without NVIDIA GPUs.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/install.sh" ]]; then
    echo "ERRORE: install.sh non trovato in ${SCRIPT_DIR}"
    exit 1
fi

chmod +x "${SCRIPT_DIR}/install.sh"

EXTRA_ARGS=("--cpu")
MODEL_ARG=""
THREAD_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            shift
            MODEL_ARG="$1"
            ;;
        --threads)
            shift
            THREAD_ARG="$1"
            ;;
        --help|-h)
            cat << 'EOF'
PRIVATE CORPORATE AI — Installer LITE (CPU-only)

UTILIZZO:
    sudo ./install-cpu.sh [OPZIONI]

OPZIONI:
    --model <nome>     Specifica il modello LLM quantizzato
    --threads <n>      Numero di thread CPU per Ollama (default: core fisici)
    --help             Mostra questo messaggio

MODELLI RACCOMANDATI PER CPU (quantizzati q4_K_M):
    RAM 8  GB  →  gemma2:2b  o  llama3.2:3b
    RAM 12 GB  →  mistral:7b-instruct-q4_K_M
    RAM 16 GB+ →  qwen2.5:7b-instruct-q4_K_M   [MIGLIORE PER ITALIANO]

NOTE SUI MODELLI q4_K_M:
    - Quantizzati a 4-bit: ~97% della qualità originale
    - Consumano ~60% meno RAM rispetto ai modelli float16
    - Nessuna GPU richiesta, inferenza su CPU con istruzioni AVX2

ESEMPI:
    sudo ./install-cpu.sh
    sudo ./install-cpu.sh --model qwen2.5:7b-instruct-q4_K_M
    sudo ./install-cpu.sh --model phi3:mini --threads 4
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

# ── Banner e info pre-avvio ───────────────────────────────────────────────────
echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   Private Corporate AI — Installer LITE      ║"
echo "  ║              (CPU-only Mode)                  ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# Verifica AVX2 — requisito fondamentale per Ollama su CPU
if ! grep -q avx2 /proc/cpuinfo 2>/dev/null; then
    echo -e "\033[1;31m  [ERROR]\033[0m  AVX2 non supportato dalla CPU."
    echo -e "\033[1;31m  [ERROR]\033[0m  Ollama richiede istruzioni AVX2 per l'inferenza CPU."
    echo -e "\033[1;33m  [INFO]\033[0m   Verifica con: grep avx2 /proc/cpuinfo"
    echo -e "\033[1;33m  [INFO]\033[0m   Sono supportate CPU x86_64 prodotte dopo il 2013."
    exit 1
fi
echo -e "  \033[0;32m[  OK ]\033[0m   AVX2 supportato dalla CPU ✓"

# Rileva RAM e suggerisci modello
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_GB=$(( RAM_KB / 1024 / 1024 ))
echo "  Memoria RAM totale: ${RAM_GB} GB"

# Mostra suggerimento modello in base alla RAM
if [[ "${RAM_GB}" -lt 8 ]]; then
    echo -e "  \033[1;31m[WARN]\033[0m   RAM bassa (${RAM_GB} GB). Minimo consigliato: 8 GB"
    echo -e "  \033[1;33m[INFO]\033[0m   Modello consigliato: gemma2:2b (~1.6 GB RAM)"
elif [[ "${RAM_GB}" -lt 12 ]]; then
    echo "  Modello ottimale per ${RAM_GB} GB RAM: llama3.2:3b (~2.0 GB)"
elif [[ "${RAM_GB}" -lt 16 ]]; then
    echo "  Modello ottimale per ${RAM_GB} GB RAM: mistral:7b-instruct-q4_K_M (~4.1 GB)"
else
    echo "  Modello ottimale per ${RAM_GB} GB RAM: qwen2.5:7b-instruct-q4_K_M (~4.4 GB) — TOP per italiano"
fi

# Informazioni thread CPU
PHYSICAL_CORES=$(lscpu | grep "Core(s) per socket" | awk '{print $NF}' 2>/dev/null || echo "4")
LOGICAL_CORES=$(nproc)
echo "  Core logici: ${LOGICAL_CORES} | Core fisici: ${PHYSICAL_CORES}"
echo "  Thread Ollama raccomandati: ${PHYSICAL_CORES} (core fisici)"
echo ""
echo -e "  \033[1;33m[NOTA]\033[0m  Prima risposta stimata: 60-180 secondi (normale per CPU)"
echo -e "  \033[1;33m[NOTA]\033[0m  Usa modelli con suffisso q4_K_M per migliori prestazioni"
echo ""

# Pre-imposta il modello se specificato da argomento
if [[ -n "${MODEL_ARG}" ]]; then
    export PRECONFIGURED_MODEL="${MODEL_ARG}"
    echo "  Modello pre-selezionato: ${MODEL_ARG}"
fi

# Pre-imposta i thread se specificati
if [[ -n "${THREAD_ARG}" ]]; then
    export PRECONFIGURED_THREADS="${THREAD_ARG}"
    echo "  Thread CPU pre-impostati: ${THREAD_ARG}"
fi

echo ""

exec "${SCRIPT_DIR}/install.sh" "${EXTRA_ARGS[@]}"
