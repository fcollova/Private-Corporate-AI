#!/usr/bin/env bash
# =============================================================================
# PRIVATE CORPORATE AI — Script di Installazione Principale
# Autore: Francesco Collovà
# Licenza: Apache 2.0
# Versione: 1.1.0
# Compatibilità: Ubuntu 22.04 LTS / 24.04 LTS (x86_64)
# =============================================================================
# Utilizzo:
#   ./install.sh              → Installazione interattiva (sceglie GPU o CPU)
#   ./install.sh --gpu        → Forza modalità FULL (GPU NVIDIA)
#   ./install.sh --cpu        → Forza modalità LITE (CPU-only)
#   ./install.sh --help       → Mostra questo messaggio
#
# Lo script gestisce TUTTO:
#   1. Rilevamento hardware (GPU NVIDIA, RAM, CPU, AVX2)
#   2. Installazione dipendenze di sistema (Docker, NVIDIA Toolkit)
#   3. Configurazione automatica del file .env
#   4. Generazione certificati SSL self-signed
#   5. Build e avvio dello stack Docker
#   6. Verifica post-installazione con healthcheck
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── Colori e formattazione ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ── Costanti ──────────────────────────────────────────────────────────────────
SCRIPT_VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/install.log"
ENV_FILE="${SCRIPT_DIR}/.env"
ENV_EXAMPLE="${SCRIPT_DIR}/.env.example"

# Soglie hardware minime
MIN_RAM_GB_GPU=32
MIN_RAM_GB_CPU=8
MIN_DISK_GB_GPU=200
MIN_DISK_GB_CPU=50
MIN_CPU_CORES=4

# Timeout healthcheck post-install (secondi)
HEALTHCHECK_TIMEOUT=300

# ── Logging ───────────────────────────────────────────────────────────────────
log() { echo -e "$*" | tee -a "${LOG_FILE}"; }
log_info()    { log "${BLUE}[INFO]${NC}    $*"; }
log_ok()      { log "${GREEN}[  OK ]${NC}   $*"; }
log_warn()    { log "${YELLOW}[ WARN]${NC}   $*"; }
log_error()   { log "${RED}[ERROR]${NC}   $*"; }
log_section() { log "\n${BOLD}${CYAN}══════════════════════════════════════════════${NC}"; log "${BOLD}${CYAN}  $*${NC}"; log "${BOLD}${CYAN}══════════════════════════════════════════════${NC}"; }
log_step()    { log "\n${BOLD}▶  $*${NC}"; }

# ── Utilità ───────────────────────────────────────────────────────────────────
command_exists() { command -v "$1" &>/dev/null; }
is_root()        { [[ "$EUID" -eq 0 ]]; }

# Genera una stringa casuale sicura (32 caratteri)
generate_secret() { tr -dc 'A-Za-z0-9!@#%^&*()_+=-' </dev/urandom | head -c 32 2>/dev/null || openssl rand -base64 24 | tr -d '/+='; }

# Spinner per operazioni lunghe
spinner() {
    local pid=$1 msg=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r  ${CYAN}${spin:$i:1}${NC}  ${DIM}${msg}...${NC}"
        sleep 0.1
    done
    printf "\r  ${GREEN}✓${NC}  ${msg}\n"
}

# ── Banner ────────────────────────────────────────────────────────────────────
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    cat << 'EOF'
  ╔═══════════════════════════════════════════════════════════╗
  ║                                                           ║
  ║         PRIVATE CORPORATE AI  —  Installazione           ║
  ║              Stack Self-Hosted per PMI                    ║
  ║                                                           ║
  ║   Ollama  •  Qdrant  •  FastAPI  •  Open WebUI  •  Nginx  ║
  ║                                                           ║
  ╚═══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    log_info "Versione script: ${SCRIPT_VERSION}"
    log_info "Directory progetto: ${SCRIPT_DIR}"
    log_info "Log: ${LOG_FILE}"
    echo ""
}

# ── Help ──────────────────────────────────────────────────────────────────────
show_help() {
    cat << EOF
${BOLD}PRIVATE CORPORATE AI — Script di Installazione v${SCRIPT_VERSION}${NC}

${BOLD}UTILIZZO:${NC}
    ./install.sh [OPZIONE]

${BOLD}OPZIONI:${NC}
    --gpu         Installa in modalità FULL (GPU NVIDIA richiesta)
    --cpu         Installa in modalità LITE (CPU-only, nessuna GPU)
    --uninstall   Rimuove lo stack e i volumi Docker
    --help        Mostra questo messaggio

${BOLD}SENZA ARGOMENTI:${NC}
    Lo script rileva automaticamente l'hardware e propone la modalità
    più adatta, con possibilità di scelta interattiva.

${BOLD}ESEMPI:${NC}
    sudo ./install.sh              # Interattivo con rilevamento auto
    sudo ./install.sh --gpu        # Forza modalità GPU
    sudo ./install.sh --cpu        # Forza modalità CPU (LITE)

${BOLD}REQUISITI:${NC}
    Sistema operativo : Ubuntu 22.04 LTS o 24.04 LTS (x86_64)
    Modalità GPU      : GPU NVIDIA 16+ GB VRAM, RAM 32+ GB
    Modalità LITE     : CPU x86_64 con AVX2, RAM 8+ GB
    Connessione rete  : Necessaria per il download di Docker e modelli LLM
EOF
}

# ── Rilevamento Hardware ──────────────────────────────────────────────────────
detect_hardware() {
    log_section "Rilevamento Hardware"

    # OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS_NAME="${NAME} ${VERSION_ID}"
    else
        OS_NAME="Unknown Linux"
    fi
    log_info "Sistema operativo: ${OS_NAME}"

    # Architettura
    ARCH=$(uname -m)
    log_info "Architettura: ${ARCH}"
    if [[ "${ARCH}" != "x86_64" ]]; then
        log_error "Architettura non supportata: ${ARCH}. Richiesta x86_64."
        exit 1
    fi

    # Ambiente WSL (Windows Subsystem for Linux)
    # NVIDIA GPU su WSL richiede configurazione specifica su Windows;
    # lo script lo segnala e forza la modalità CPU per sicurezza.
    IS_WSL=false
    WSL_VERSION=""
    if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null ||        grep -qiE "microsoft|wsl" /proc/sys/kernel/osrelease 2>/dev/null ||        [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        IS_WSL=true
        if grep -qi "wsl2" /proc/version 2>/dev/null; then
            WSL_VERSION="WSL2"
        else
            WSL_VERSION="WSL1"
        fi
        log_warn "Ambiente WSL rilevato: ${WSL_VERSION}"
        log_warn "Su WSL la GPU NVIDIA richiede configurazione aggiuntiva su Windows."
        log_warn "In caso di dubbio verrà suggerita la modalità LITE (CPU-only)."
    fi

    # CPU
    CPU_CORES=$(nproc)
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    HAS_AVX2=$(grep -c "avx2" /proc/cpuinfo 2>/dev/null || echo "0")
    HAS_AVX512=$(grep -c "avx512f" /proc/cpuinfo 2>/dev/null || echo "0")
    log_info "CPU: ${CPU_MODEL}"
    log_info "Core logici: ${CPU_CORES}"
    log_info "AVX2: $([ "${HAS_AVX2}" -gt 0 ] && echo 'Supportato ✓' || echo 'Non supportato ✗')"
    log_info "AVX512: $([ "${HAS_AVX512}" -gt 0 ] && echo 'Supportato ✓' || echo 'Non supportato')"

    # RAM
    RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    RAM_GB=$(( RAM_KB / 1024 / 1024 ))
    log_info "RAM totale: ${RAM_GB} GB"

    # Disco libero nella directory del progetto
    DISK_FREE_GB=$(df -BG "${SCRIPT_DIR}" | awk 'NR==2 {gsub("G","",$4); print $4}')
    log_info "Spazio disco libero (${SCRIPT_DIR}): ${DISK_FREE_GB} GB"

    # GPU NVIDIA
    HAS_NVIDIA_GPU=false
    NVIDIA_GPU_NAME=""
    NVIDIA_VRAM_GB=0
    NVIDIA_DRIVER_VERSION=""

    if command_exists nvidia-smi; then
        NVIDIA_GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "")
        if [[ -n "${NVIDIA_GPU_NAME}" ]]; then
            NVIDIA_VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
            NVIDIA_VRAM_GB=$(( NVIDIA_VRAM_MB / 1024 ))
            NVIDIA_DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "")

            if [[ "${IS_WSL}" == "true" ]]; then
                # Su WSL nvidia-smi funziona (driver Windows passthrough) ma
                # nvidia-container-cli non riesce ad accedere agli adapter GPU
                # a meno di configurazione specifica. Segnaliamo ma non marchiamo
                # come "usabile" di default per evitare l'errore OCI runtime.
                log_warn "GPU rilevata su WSL: ${NVIDIA_GPU_NAME} (${NVIDIA_VRAM_GB} GB VRAM)"
                log_warn "La GPU NON è utilizzabile automaticamente nei container su WSL."
                log_warn "Vedi DEPLOYMENT_GUIDE.md sezione WSL per la configurazione manuale."
                HAS_NVIDIA_GPU=false   # sicuro: lo script sceglierà CPU di default
                NVIDIA_GPU_NAME_WSL="${NVIDIA_GPU_NAME}"  # conserva per il messaggio
            else
                HAS_NVIDIA_GPU=true
                log_ok "GPU NVIDIA rilevata: ${NVIDIA_GPU_NAME} (${NVIDIA_VRAM_GB} GB VRAM)"
                log_info "Driver NVIDIA: ${NVIDIA_DRIVER_VERSION}"
            fi
        fi
    fi

    if [[ "${HAS_NVIDIA_GPU}" == "false" ]] && [[ "${IS_WSL}" == "false" ]]; then
        log_info "GPU NVIDIA: Non rilevata (o driver non installati)"
    fi

    echo ""
}

# ── Selezione Modalità ────────────────────────────────────────────────────────
select_deploy_mode() {
    log_section "Selezione Modalità di Deploy"

    # Se la modalità è già stata forzata da argomento CLI, validala e ritorna
    if [[ -n "${FORCED_MODE:-}" ]]; then
        DEPLOY_MODE="${FORCED_MODE}"
        log_info "Modalità forzata da argomento: ${DEPLOY_MODE}"

        if [[ "${DEPLOY_MODE}" == "gpu" ]] && [[ "${HAS_NVIDIA_GPU}" == "false" ]]; then
            if [[ "${IS_WSL}" == "true" ]]; then
                log_warn "Modalità GPU richiesta ma sei su WSL (${WSL_VERSION})."
                log_warn "Su WSL la GPU nei container richiede:"
                log_warn "  1. Driver NVIDIA aggiornati su Windows (>=472.12)"
                log_warn "  2. CUDA Toolkit per WSL2 installato su Windows"
                log_warn "  3. Docker Desktop con GPU pass-through abilitato"
                log_warn "  4. nvidia-container-toolkit installato nel WSL"
                log_warn "Consulta DEPLOYMENT_GUIDE.md sezione WSL per i dettagli."
                log_warn ""
                log_warn "In alternativa usa la modalità LITE (CPU-only): ./install-cpu.sh"
            else
                log_warn "Modalità GPU richiesta ma nessuna GPU NVIDIA rilevata."
                log_warn "Assicurati che i driver NVIDIA siano installati e la GPU sia presente."
            fi
            echo -ne "  Vuoi procedere comunque con la modalità GPU? [s/N] "
            read -r confirm
            if [[ ! "${confirm}" =~ ^[sS]$ ]]; then
                log_error "Installazione annullata."
                exit 1
            fi
        fi
        return
    fi

    # Scelta automatica basata sull'hardware rilevato
    AUTO_MODE="cpu"
    AUTO_REASON="nessuna GPU NVIDIA rilevata"

    if [[ "${IS_WSL}" == "true" ]]; then
        # Su WSL forziamo sempre CPU di default per evitare l'errore
        # "nvidia-container-cli: WSL environment detected but no adapters were found"
        AUTO_MODE="cpu"
        if [[ -n "${NVIDIA_GPU_NAME_WSL:-}" ]]; then
            AUTO_REASON="WSL rilevato — GPU (${NVIDIA_GPU_NAME_WSL}) non usabile nei container senza configurazione Windows aggiuntiva"
        else
            AUTO_REASON="WSL rilevato — modalità LITE (CPU-only) consigliata"
        fi
    elif [[ "${HAS_NVIDIA_GPU}" == "true" ]] && [[ "${NVIDIA_VRAM_GB}" -ge 16 ]] && [[ "${RAM_GB}" -ge "${MIN_RAM_GB_GPU}" ]]; then
        AUTO_MODE="gpu"
        AUTO_REASON="GPU ${NVIDIA_GPU_NAME} con ${NVIDIA_VRAM_GB} GB VRAM rilevata"
    elif [[ "${HAS_NVIDIA_GPU}" == "true" ]] && [[ "${NVIDIA_VRAM_GB}" -lt 16 ]]; then
        AUTO_MODE="cpu"
        AUTO_REASON="GPU rilevata ma VRAM insufficiente (${NVIDIA_VRAM_GB} GB < 16 GB minimi)"
    fi

    echo ""
    echo -e "  ${BOLD}Hardware rilevato suggerisce:${NC} ${CYAN}Modalità ${AUTO_MODE^^}${NC}"
    echo -e "  ${DIM}Motivo: ${AUTO_REASON}${NC}"
    echo ""
    echo -e "  ${BOLD}Opzioni disponibili:${NC}"
    echo -e "    ${GREEN}1)${NC} ${BOLD}Modalità FULL — GPU${NC}"
    echo -e "       ${DIM}Richiede GPU NVIDIA con CUDA (16+ GB VRAM)${NC}"
    echo -e "       ${DIM}Modelli: gemma2:9b, mistral:7b, deepseek-r1:14b${NC}"
    echo -e "       ${DIM}Risposte: 2-15 secondi${NC}"
    echo ""
    echo -e "    ${YELLOW}2)${NC} ${BOLD}Modalità LITE — CPU-only${NC} (nessuna GPU richiesta)"
    echo -e "       ${DIM}Solo CPU e RAM (minimo 8 GB RAM)${NC}"
    echo -e "       ${DIM}Modelli: phi3:mini, gemma2:2b, mistral:7b-instruct-q4_K_M${NC}"
    echo -e "       ${DIM}Risposte: 30-180 secondi${NC}"
    echo ""

    local default_choice=1
    [[ "${AUTO_MODE}" == "cpu" ]] && default_choice=2

    echo -ne "  ${BOLD}Scelta [1/2, default=${default_choice}]:${NC} "
    read -r choice
    choice="${choice:-${default_choice}}"

    case "${choice}" in
        1) DEPLOY_MODE="gpu" ;;
        2) DEPLOY_MODE="cpu" ;;
        *)
            log_warn "Scelta non valida '${choice}', uso default: ${AUTO_MODE}"
            DEPLOY_MODE="${AUTO_MODE}"
            ;;
    esac

    log_ok "Modalità selezionata: ${DEPLOY_MODE^^}"
}

# ── Selezione Modello LLM ─────────────────────────────────────────────────────
select_llm_model() {
    log_section "Selezione Modello LLM"

    if [[ "${DEPLOY_MODE}" == "gpu" ]]; then
        echo -e "  ${BOLD}Modelli disponibili per modalità GPU:${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} ${BOLD}gemma2:9b${NC}           ${DIM}~8 GB VRAM  — Ottimo ITA/ENG, RAG documentale${NC} ${GREEN}[CONSIGLIATO]${NC}"
        echo -e "  ${GREEN}2)${NC} ${BOLD}mistral:7b${NC}          ${DIM}~6 GB VRAM  — Veloce e bilanciato${NC}"
        echo -e "  ${GREEN}3)${NC} ${BOLD}llama3.1:8b${NC}         ${DIM}~6 GB VRAM  — Meta, multilingua${NC}"
        echo -e "  ${GREEN}4)${NC} ${BOLD}deepseek-r1:14b${NC}     ${DIM}~12 GB VRAM — Ragionamento avanzato${NC}"
        echo -e "  ${GREEN}5)${NC} ${BOLD}mixtral:8x7b${NC}        ${DIM}~26 GB VRAM — MoE, qualità massima (>24 GB richiesti)${NC}"
        echo -e "  ${GREEN}6)${NC} ${BOLD}Modello personalizzato${NC}"
        echo ""
        echo -ne "  ${BOLD}Scelta [1-6, default=1]:${NC} "
        read -r choice
        case "${choice:-1}" in
            1) LLM_MODEL="gemma2:9b" ;;
            2) LLM_MODEL="mistral:7b" ;;
            3) LLM_MODEL="llama3.1:8b" ;;
            4) LLM_MODEL="deepseek-r1:14b" ;;
            5) LLM_MODEL="mixtral:8x7b" ;;
            6)
                echo -ne "  Inserisci il nome del modello Ollama (es: phi3:medium): "
                read -r LLM_MODEL
                LLM_MODEL="${LLM_MODEL:-gemma2:9b}"
                ;;
            *) LLM_MODEL="gemma2:9b" ;;
        esac
    else
        # Modalità LITE (CPU)
        # Suggerisce modello in base alla RAM disponibile
        local suggested_model="phi3:mini"
        local suggested_reason="RAM disponibile: ${RAM_GB} GB"
        if [[ "${RAM_GB}" -ge 16 ]]; then
            suggested_model="qwen2.5:7b-instruct-q4_K_M"
            suggested_reason="RAM >= 16 GB: puoi usare il modello migliore per italiano"
        elif [[ "${RAM_GB}" -ge 12 ]]; then
            suggested_model="mistral:7b-instruct-q4_K_M"
            suggested_reason="RAM >= 12 GB: ottimo bilanciamento qualità/velocità"
        elif [[ "${RAM_GB}" -ge 8 ]]; then
            suggested_model="llama3.2:3b"
            suggested_reason="RAM >= 8 GB: modello leggero e capace"
        fi

        echo -e "  ${BOLD}Modelli raccomandati per modalità LITE (CPU-only):${NC}"
        echo -e "  ${DIM}Tutti i modelli q4_K_M sono quantizzati a 4-bit: ~97% qualità, 60% meno RAM${NC}"
        echo ""
        echo -e "  ${GREEN}1)${NC} ${BOLD}gemma2:2b${NC}                     ${DIM}~1.6 GB RAM — Ultra-compatto, test${NC}"
        echo -e "  ${GREEN}2)${NC} ${BOLD}phi3:mini${NC}                     ${DIM}~2.3 GB RAM — Microsoft, veloce${NC}"
        echo -e "  ${GREEN}3)${NC} ${BOLD}llama3.2:3b${NC}                   ${DIM}~2.0 GB RAM — Meta, bilanciato${NC}"
        echo -e "  ${GREEN}4)${NC} ${BOLD}mistral:7b-instruct-q4_K_M${NC}   ${DIM}~4.1 GB RAM — Buona qualità ITA${NC} ${YELLOW}[16GB RAM]${NC}"
        echo -e "  ${GREEN}5)${NC} ${BOLD}qwen2.5:7b-instruct-q4_K_M${NC}   ${DIM}~4.4 GB RAM — Top per italiano${NC} ${GREEN}[CONSIGLIATO 16GB+]${NC}"
        echo -e "  ${GREEN}6)${NC} ${BOLD}Modello personalizzato${NC}"
        echo ""
        echo -e "  ${DIM}Suggerimento basato sulla RAM (${RAM_GB} GB): ${BOLD}${suggested_model}${NC}"
        echo -e "  ${DIM}(${suggested_reason})${NC}"
        echo ""
        echo -ne "  ${BOLD}Scelta [1-6, default basato su RAM]:${NC} "
        read -r choice

        local default_choice=2
        [[ "${RAM_GB}" -ge 16 ]] && default_choice=5
        [[ "${RAM_GB}" -ge 12 ]] && [[ "${RAM_GB}" -lt 16 ]] && default_choice=4
        [[ "${RAM_GB}" -ge 8  ]] && [[ "${RAM_GB}" -lt 12 ]] && default_choice=3

        case "${choice:-${default_choice}}" in
            1) LLM_MODEL="gemma2:2b" ;;
            2) LLM_MODEL="phi3:mini" ;;
            3) LLM_MODEL="llama3.2:3b" ;;
            4) LLM_MODEL="mistral:7b-instruct-q4_K_M" ;;
            5) LLM_MODEL="qwen2.5:7b-instruct-q4_K_M" ;;
            6)
                echo -ne "  Inserisci il nome del modello Ollama (es: phi3:mini): "
                read -r LLM_MODEL
                LLM_MODEL="${LLM_MODEL:-phi3:mini}"
                ;;
            *) LLM_MODEL="${suggested_model}" ;;
        esac
    fi

    # Modello embedding (fisso ma mostriamo info)
    EMBEDDING_MODEL="nomic-embed-text"
    log_ok "Modello LLM selezionato: ${LLM_MODEL}"
    log_info "Modello Embedding: ${EMBEDDING_MODEL} (274 MB, multilingua)"
}

# ── Configurazione Parametri Avanzati ─────────────────────────────────────────
configure_advanced() {
    log_section "Configurazione Avanzata"

    echo -e "  ${BOLD}Vuoi personalizzare i parametri avanzati?${NC}"
    echo -e "  ${DIM}(Temperatura, dimensione chunk, hostname, porte SSL...)${NC}"
    echo -ne "  ${BOLD}[s/N, default=N]:${NC} "
    read -r advanced_choice

    # Valori default
    LLM_TEMPERATURE="0.2"
    NGINX_HOST="localhost"
    NGINX_HTTP_PORT="80"
    NGINX_HTTPS_PORT="443"
    WEBUI_AUTH="true"

    # Parametri adattivi in base alla modalità
    if [[ "${DEPLOY_MODE}" == "gpu" ]]; then
        LLM_CONTEXT_WINDOW="4096"
        CHUNK_SIZE="1000"
        CHUNK_OVERLAP="200"
        TOP_K_RESULTS="5"
    else
        LLM_CONTEXT_WINDOW="2048"
        CHUNK_SIZE="700"
        CHUNK_OVERLAP="150"
        TOP_K_RESULTS="3"
    fi

    # Calcola thread CPU ottimali per modalità LITE
    OLLAMA_CPU_THREADS="0"
    if [[ "${DEPLOY_MODE}" == "cpu" ]]; then
        # Usa i core fisici (non logici) per evitare hyperthreading overhead
        PHYSICAL_CORES=$(lscpu | grep "Core(s) per socket" | awk '{print $NF}')
        SOCKETS=$(lscpu | grep "Socket(s)" | awk '{print $NF}')
        PHYSICAL_TOTAL=$(( PHYSICAL_CORES * SOCKETS ))
        OLLAMA_CPU_THREADS="${PHYSICAL_TOTAL}"
        log_info "Thread CPU fisici rilevati: ${PHYSICAL_TOTAL} (hyperthreading escluso)"
    fi

    if [[ "${advanced_choice}" =~ ^[sS]$ ]]; then
        echo ""
        echo -e "  ${DIM}Lascia vuoto per usare il valore di default mostrato tra []${NC}"
        echo ""

        echo -ne "  Temperatura LLM (0.0-1.0) [${LLM_TEMPERATURE}]: "
        read -r v; LLM_TEMPERATURE="${v:-${LLM_TEMPERATURE}}"

        echo -ne "  Contesto LLM in token [${LLM_CONTEXT_WINDOW}]: "
        read -r v; LLM_CONTEXT_WINDOW="${v:-${LLM_CONTEXT_WINDOW}}"

        echo -ne "  Dimensione chunk documenti (caratteri) [${CHUNK_SIZE}]: "
        read -r v; CHUNK_SIZE="${v:-${CHUNK_SIZE}}"

        echo -ne "  Chunk recuperati per query (top-k) [${TOP_K_RESULTS}]: "
        read -r v; TOP_K_RESULTS="${v:-${TOP_K_RESULTS}}"

        echo -ne "  Hostname/dominio server [${NGINX_HOST}]: "
        read -r v; NGINX_HOST="${v:-${NGINX_HOST}}"

        echo -ne "  Porta HTTP [${NGINX_HTTP_PORT}]: "
        read -r v; NGINX_HTTP_PORT="${v:-${NGINX_HTTP_PORT}}"

        echo -ne "  Porta HTTPS [${NGINX_HTTPS_PORT}]: "
        read -r v; NGINX_HTTPS_PORT="${v:-${NGINX_HTTPS_PORT}}"

        if [[ "${DEPLOY_MODE}" == "cpu" ]]; then
            echo -ne "  Thread CPU per Ollama (0=auto, consigliato=${OLLAMA_CPU_THREADS}) [${OLLAMA_CPU_THREADS}]: "
            read -r v; OLLAMA_CPU_THREADS="${v:-${OLLAMA_CPU_THREADS}}"
        fi
    fi

    log_ok "Parametri configurati"
}

# ── Verifica Requisiti ────────────────────────────────────────────────────────
check_requirements() {
    log_section "Verifica Requisiti"
    local errors=0

    # Verifica OS
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "${ID}" != "ubuntu" ]]; then
            log_warn "OS non Ubuntu (${ID}). Alcune dipendenze potrebbero installarsi diversamente."
        fi
    fi

    # Verifica root/sudo
    if ! is_root; then
        log_error "Questo script deve essere eseguito come root o con sudo"
        log_error "Esegui: sudo ./install.sh"
        exit 1
    fi

    # Verifica RAM
    if [[ "${DEPLOY_MODE}" == "gpu" ]] && [[ "${RAM_GB}" -lt "${MIN_RAM_GB_GPU}" ]]; then
        log_warn "RAM insufficiente per modalità GPU: ${RAM_GB} GB < ${MIN_RAM_GB_GPU} GB minimi"
        log_warn "Lo stack potrebbe non avviarsi correttamente"
        (( errors++ )) || true
    fi
    if [[ "${DEPLOY_MODE}" == "cpu" ]] && [[ "${RAM_GB}" -lt "${MIN_RAM_GB_CPU}" ]]; then
        log_error "RAM insufficiente per modalità LITE: ${RAM_GB} GB < ${MIN_RAM_GB_CPU} GB minimi"
        (( errors++ )) || true
    fi
    [[ "${errors}" -eq 0 ]] && log_ok "RAM: ${RAM_GB} GB ✓"

    # Verifica disco
    local min_disk=${MIN_DISK_GB_CPU}
    [[ "${DEPLOY_MODE}" == "gpu" ]] && min_disk=${MIN_DISK_GB_GPU}
    if [[ "${DISK_FREE_GB}" -lt "${min_disk}" ]]; then
        log_warn "Spazio disco basso: ${DISK_FREE_GB} GB liberi (consigliati ${min_disk} GB)"
    else
        log_ok "Spazio disco: ${DISK_FREE_GB} GB liberi ✓"
    fi

    # Verifica CPU cores
    if [[ "${CPU_CORES}" -lt "${MIN_CPU_CORES}" ]]; then
        log_warn "CPU con pochi core: ${CPU_CORES} (consigliati almeno ${MIN_CPU_CORES})"
    else
        log_ok "CPU cores: ${CPU_CORES} ✓"
    fi

    # Verifica AVX2 (necessario per Ollama CPU)
    if [[ "${HAS_AVX2}" -eq 0 ]]; then
        log_error "AVX2 non supportato dalla CPU — Ollama richiede AVX2 per l'inferenza CPU"
        log_error "Questo sistema non è compatibile con la modalità LITE"
        exit 1
    fi
    log_ok "AVX2: Supportato ✓"

    # Verifica connettività internet
    log_info "Verifica connettività internet..."
    if ! curl -s --connect-timeout 5 https://registry.hub.docker.com > /dev/null 2>&1; then
        log_error "Nessuna connessione internet rilevata. Il download di Docker e dei modelli richiede internet."
        exit 1
    fi
    log_ok "Connettività internet ✓"

    if [[ "${errors}" -gt 0 ]]; then
        echo -ne "  ${YELLOW}Ci sono ${errors} avvisi. Continuare? [s/N]:${NC} "
        read -r confirm
        if [[ ! "${confirm}" =~ ^[sS]$ ]]; then
            log_error "Installazione annullata."
            exit 1
        fi
    fi
}

# ── Installazione Docker ──────────────────────────────────────────────────────
install_docker() {
    log_step "Installazione Docker Engine"

    if command_exists docker && docker compose version &>/dev/null 2>&1; then
        local docker_ver; docker_ver=$(docker --version | cut -d' ' -f3 | tr -d ',')
        log_ok "Docker già installato: ${docker_ver} — skip"
        return
    fi

    log_info "Installazione Docker da repository ufficiale..."
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release

    # Rimuovi versioni precedenti
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        apt-get remove -y -qq "$pkg" 2>/dev/null || true
    done

    # Aggiungi repository Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    # Aggiungi utente corrente al gruppo docker (se non root)
    local REAL_USER="${SUDO_USER:-$USER}"
    if [[ "${REAL_USER}" != "root" ]]; then
        usermod -aG docker "${REAL_USER}"
        log_info "Utente '${REAL_USER}' aggiunto al gruppo 'docker'"
        log_warn "Per usare Docker senza sudo in futuro: newgrp docker (o riavvia la sessione)"
    fi

    # Abilita e avvia Docker
    systemctl enable docker --quiet
    systemctl start docker

    log_ok "Docker installato: $(docker --version)"
    log_ok "Docker Compose: $(docker compose version)"
}

# ── Installazione NVIDIA Toolkit ──────────────────────────────────────────────
install_nvidia_toolkit() {
    if [[ "${DEPLOY_MODE}" != "gpu" ]]; then
        log_info "Modalità LITE — skip NVIDIA Container Toolkit"
        return
    fi

    log_step "Configurazione NVIDIA Container Toolkit"

    # Verifica driver
    if ! command_exists nvidia-smi; then
        log_warn "nvidia-smi non trovato. Installazione driver NVIDIA..."
        apt-get update -qq
        apt-get install -y -qq ubuntu-drivers-common
        ubuntu-drivers autoinstall
        log_warn "Driver NVIDIA installati. Potrebbe essere necessario un riavvio."
        log_warn "Dopo il riavvio, esegui nuovamente questo script."
        echo -ne "  ${YELLOW}Riavvia ora? [s/N]:${NC} "
        read -r reboot_now
        if [[ "${reboot_now}" =~ ^[sS]$ ]]; then
            log_info "Riavvio in corso..."
            reboot
        fi
    fi

    # Controlla se nvidia-container-toolkit è già installato
    if command_exists nvidia-ctk; then
        log_ok "NVIDIA Container Toolkit già installato — skip"
        # Assicura che la configurazione Docker sia corretta
        nvidia-ctk runtime configure --runtime=docker --quiet 2>/dev/null || true
        return
    fi

    log_info "Installazione NVIDIA Container Toolkit..."

    # Repository NVIDIA
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>/dev/null

    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq nvidia-container-toolkit

    # Configura runtime Docker per GPU
    nvidia-ctk runtime configure --runtime=docker --quiet
    systemctl restart docker
    sleep 2

    # Test GPU nel container
    log_info "Test GPU nel container Docker..."
    if docker run --rm --gpus all nvidia/cuda:12.3.0-base-ubuntu22.04 nvidia-smi \
        --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null; then
        log_ok "GPU accessibile nel container ✓"
    else
        log_warn "Test GPU nel container fallito — verifica manualmente: docker run --rm --gpus all nvidia/cuda:12.3.0-base-ubuntu22.04 nvidia-smi"
    fi
}

# ── Generazione Certificati SSL ───────────────────────────────────────────────
generate_ssl_certs() {
    log_step "Generazione Certificati SSL"

    local ssl_dir="${SCRIPT_DIR}/nginx/ssl"
    mkdir -p "${ssl_dir}"

    if [[ -f "${ssl_dir}/server.crt" ]] && [[ -f "${ssl_dir}/server.key" ]]; then
        log_ok "Certificati SSL già presenti — skip"
        return
    fi

    log_info "Generazione certificato self-signed (valido 365 giorni)..."

    # Determina il Subject Alternative Name
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "127.0.0.1")

    openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
        -keyout "${ssl_dir}/server.key" \
        -out "${ssl_dir}/server.crt" \
        -subj "/C=IT/ST=Italia/L=Roma/O=CorporateAI/OU=IT/CN=${NGINX_HOST}" \
        -addext "subjectAltName=IP:127.0.0.1,IP:${server_ip},DNS:localhost,DNS:${NGINX_HOST}" \
        2>/dev/null

    chmod 600 "${ssl_dir}/server.key"
    chmod 644 "${ssl_dir}/server.crt"

    log_ok "Certificati SSL generati: ${ssl_dir}/"
    log_info "  server.crt — Certificato pubblico"
    log_info "  server.key — Chiave privata (permessi 600)"
    log_warn "Questi sono certificati self-signed. Per produzione usa Let's Encrypt."
}

# ── Generazione File .env ─────────────────────────────────────────────────────
generate_env_file() {
    log_step "Generazione File .env"

    if [[ -f "${ENV_FILE}" ]]; then
        log_warn "File .env già esistente — backup in .env.backup.$(date +%Y%m%d%H%M%S)"
        cp "${ENV_FILE}" "${ENV_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    # Genera secret key sicure
    local QDRANT_API_KEY; QDRANT_API_KEY=$(generate_secret)
    local WEBUI_SECRET_KEY; WEBUI_SECRET_KEY=$(generate_secret)

    log_info "Generazione credenziali sicure..."

    cat > "${ENV_FILE}" << ENVEOF
# =============================================================================
# PRIVATE CORPORATE AI — Configurazione Generata Automaticamente
# Generato: $(date "+%Y-%m-%d %H:%M:%S")
# Modalità: ${DEPLOY_MODE^^}
# Modello LLM: ${LLM_MODEL}
# =============================================================================
# ⚠️  NON committare questo file su Git (già in .gitignore)
# =============================================================================

# Modalità deploy
DEPLOY_MODE=${DEPLOY_MODE}

# LLM
LLM_MODEL=${LLM_MODEL}
EMBEDDING_MODEL=${EMBEDDING_MODEL}
LLM_TEMPERATURE=${LLM_TEMPERATURE}
LLM_CONTEXT_WINDOW=${LLM_CONTEXT_WINDOW}
OLLAMA_CPU_THREADS=${OLLAMA_CPU_THREADS}
OLLAMA_NUM_GPU_LAYERS=0

# Qdrant
QDRANT_HOST=qdrant
QDRANT_PORT=6333
QDRANT_COLLECTION_NAME=corporate_docs
QDRANT_API_KEY=${QDRANT_API_KEY}

# RAG Pipeline
CHUNK_SIZE=${CHUNK_SIZE}
CHUNK_OVERLAP=${CHUNK_OVERLAP}
TOP_K_RESULTS=${TOP_K_RESULTS}

# Open WebUI
WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}
WEBUI_AUTH=${WEBUI_AUTH}
WEBUI_DEFAULT_USER_ROLE=user

# Nginx
NGINX_HOST=${NGINX_HOST}
NGINX_HTTP_PORT=${NGINX_HTTP_PORT}
NGINX_HTTPS_PORT=${NGINX_HTTPS_PORT}

# Generale
TZ=Europe/Rome
LOG_LEVEL=INFO
UPLOAD_DIR=/app/uploads
ENVEOF

    chmod 600 "${ENV_FILE}"
    log_ok "File .env generato con credenziali sicure"
    log_info "  QDRANT_API_KEY: ${QDRANT_API_KEY:0:8}...  (generata casualmente)"
    log_info "  WEBUI_SECRET_KEY: ${WEBUI_SECRET_KEY:0:8}...  (generata casualmente)"
}

# ── Rimuove il blocco GPU da docker-compose.yaml in modalità CPU ─────────────
# Docker Compose v2 fa il MERGE dei blocchi deploy.resources invece di
# sovrascriverli con l'override — quindi il blocco nvidia rimane attivo
# anche con docker-compose.lite.yaml. La soluzione affidabile è rimuoverlo
# direttamente dal file base quando DEPLOY_MODE=cpu.
patch_compose_for_cpu() {
    if [[ "${DEPLOY_MODE}" != "cpu" ]]; then
        return
    fi

    local compose_file="${SCRIPT_DIR}/docker-compose.yaml"

    # Controlla se il blocco nvidia è ancora presente
    if ! grep -q "driver: nvidia" "${compose_file}" 2>/dev/null; then
        log_info "Blocco GPU già assente da docker-compose.yaml — skip"
        return
    fi

    log_step "Rimozione blocco GPU da docker-compose.yaml (modalità LITE)"

    # Backup prima di modificare
    cp "${compose_file}" "${compose_file}.gpu-backup"

    # Approccio riga-per-riga in puro bash:
    # Legge il file e salta le righe del blocco GPU di Ollama.
    # Il blocco inizia alla riga con "# Accelerazione GPU NVIDIA" (o "deploy:")
    # preceduta da 4 spazi, e finisce dopo "capabilities: [gpu]".
    local tmp_file
    tmp_file=$(mktemp)
    local skip=false

    while IFS= read -r line; do
        # Inizia a saltare quando trova il commento o il deploy block GPU
        if [[ "${line}" == "    # Accelerazione GPU NVIDIA"* ]] || \
           [[ "${skip}" == "false" && "${line}" == "    # In modalita"* && \
              $(grep -c "driver: nvidia" "${compose_file}") -gt 0 ]]; then
            skip=true
        fi

        # Riga "    deploy:" senza commento precedente — potrebbe essere il blocco GPU
        # Lo identifichiamo guardando se la riga successiva porta a nvidia
        if [[ "${skip}" == "false" && "${line}" =~ ^"    deploy:"$ ]]; then
            # Peek: legge il resto del file cercando "driver: nvidia" entro 6 righe
            # Per semplicità usiamo un flag esterno impostato da grep
            if grep -A 6 "^    deploy:" "${compose_file}" | grep -q "driver: nvidia"; then
                skip=true
            fi
        fi

        if [[ "${skip}" == "false" ]]; then
            echo "${line}" >> "${tmp_file}"
        fi

        # Smette di saltare dopo "capabilities: [gpu]"
        if [[ "${skip}" == "true" && "${line}" == *"capabilities: [gpu]"* ]]; then
            skip=false
        fi
    done < "${compose_file}"

    mv "${tmp_file}" "${compose_file}"

    if grep -q "driver: nvidia" "${compose_file}" 2>/dev/null; then
        log_warn "Rimozione automatica non riuscita — rimuovi manualmente il blocco:"
        log_warn "  deploy:"
        log_warn "    resources:"
        log_warn "      reservations:"
        log_warn "        devices:"
        log_warn "          - driver: nvidia"
        log_warn "            count: all"
        log_warn "            capabilities: [gpu]"
        log_warn "dal servizio 'ollama' in docker-compose.yaml, poi riavvia."
    else
        log_ok "Blocco GPU rimosso da docker-compose.yaml ✓"
        log_info "  Backup: docker-compose.yaml.gpu-backup"
    fi
}

# ── Costruisce l'array del comando compose (evita word-splitting su -f flags) ─
# NOTA: usare sempre "${COMPOSE_CMD[@]}" (con le virgolette) per espandere
#       correttamente un array che contiene flag con spazi nel valore.
build_compose_cmd() {
    if [[ "${DEPLOY_MODE}" == "gpu" ]]; then
        COMPOSE_CMD=(docker compose --env-file .env)
        COMPOSE_FILES="docker-compose.yaml"
    else
        COMPOSE_CMD=(docker compose
            -f docker-compose.yaml
            -f docker-compose.lite.yaml
            --env-file .env)
        COMPOSE_FILES="docker-compose.yaml + docker-compose.lite.yaml"
    fi
}

# ── Build e Avvio Stack ───────────────────────────────────────────────────────
build_and_start() {
    log_section "Build e Avvio Stack Docker"
    cd "${SCRIPT_DIR}"

    build_compose_cmd

    log_info "File Compose: ${COMPOSE_FILES}"
    log_info "Comando: ${COMPOSE_CMD[*]}"

    # Pull immagini base
    log_step "Download immagini Docker base..."
    "${COMPOSE_CMD[@]}" pull --quiet 2>&1 | tee -a "${LOG_FILE}" &
    local pull_pid=$!
    spinner "${pull_pid}" "Download immagini Docker"
    wait "${pull_pid}" || log_warn "Alcune immagini potrebbero non essere state scaricate"

    # Build RAG Backend custom
    log_step "Build immagine RAG Backend..."
    "${COMPOSE_CMD[@]}" build rag_backend 2>&1 | tee -a "${LOG_FILE}" &
    local build_pid=$!
    spinner "${build_pid}" "Build RAG Backend"
    wait "${build_pid}"

    # Avvio servizi
    log_step "Avvio servizi..."
    "${COMPOSE_CMD[@]}" up -d 2>&1 | tee -a "${LOG_FILE}"
    log_ok "Stack avviato"

    # Salva il comando stringa per uso futuro (uninstall.sh, Makefile)
    echo "${COMPOSE_CMD[*]}" > "${SCRIPT_DIR}/.compose_cmd"
    log_info "Comando compose salvato in .compose_cmd per uso futuro"
}

# ── Healthcheck Post-Installazione ────────────────────────────────────────────
wait_for_healthy() {
    log_section "Verifica Post-Installazione"

    log_info "Attesa avvio servizi (timeout: ${HEALTHCHECK_TIMEOUT}s)..."
    log_info "Il download dei modelli LLM potrebbe richiedere diversi minuti..."
    echo ""

    local elapsed=0
    local check_interval=10
    local services=("corporate_ai_ollama" "corporate_ai_qdrant" "corporate_ai_rag")

    while [[ "${elapsed}" -lt "${HEALTHCHECK_TIMEOUT}" ]]; do
        local all_healthy=true

        for svc in "${services[@]}"; do
            local status
            status=$(docker inspect --format='{{.State.Health.Status}}' "${svc}" 2>/dev/null || echo "not_found")
            if [[ "${status}" != "healthy" ]]; then
                all_healthy=false
                printf "\r  ${YELLOW}⏳${NC}  Attesa servizi... [${elapsed}s/${HEALTHCHECK_TIMEOUT}s] | ${svc}: ${status}"
                break
            fi
        done

        if [[ "${all_healthy}" == "true" ]]; then
            echo ""
            log_ok "Tutti i servizi core sono healthy!"
            break
        fi

        sleep "${check_interval}"
        elapsed=$(( elapsed + check_interval ))
    done

    if [[ "${elapsed}" -ge "${HEALTHCHECK_TIMEOUT}" ]]; then
        echo ""
        log_warn "Timeout healthcheck. Alcuni servizi potrebbero ancora essere in avvio."
        log_warn "Controlla con: docker compose ps"
        log_warn "I modelli LLM potrebbero ancora essere in download."
    fi

    # Test API RAG Backend
    log_step "Test API RAG Backend..."
    local retries=0
    while [[ "${retries}" -lt 10 ]]; do
        local health_response
        health_response=$(curl -sk https://localhost/api/rag/health 2>/dev/null || echo "")
        if [[ -n "${health_response}" ]]; then
            log_ok "API RAG Backend risponde ✓"
            echo ""
            echo -e "  ${DIM}${health_response}${NC}" | python3 -m json.tool 2>/dev/null || echo "  ${health_response}"
            break
        fi
        (( retries++ ))
        sleep 5
    done
}

# ── Riepilogo Finale ──────────────────────────────────────────────────────────
show_summary() {
    log_section "Installazione Completata"

    local server_ip
    server_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")

    echo -e ""
    echo -e "${BOLD}${GREEN}  ✅ Private Corporate AI è operativo!${NC}"
    echo -e ""
    echo -e "${BOLD}  📋 Riepilogo Configurazione:${NC}"
    echo -e "  ┌─────────────────────────────────────────────┐"
    echo -e "  │  Modalità:       ${BOLD}${DEPLOY_MODE^^}${NC}"
    echo -e "  │  Modello LLM:    ${BOLD}${LLM_MODEL}${NC}"
    echo -e "  │  Embedding:      ${EMBEDDING_MODEL}"
    echo -e "  │  Contesto:       ${LLM_CONTEXT_WINDOW} token"
    echo -e "  │  Chunk size:     ${CHUNK_SIZE} caratteri"
    echo -e "  │  Top-K chunks:   ${TOP_K_RESULTS}"
    echo -e "  └─────────────────────────────────────────────┘"
    echo -e ""
    echo -e "${BOLD}  🌐 Accesso:${NC}"
    echo -e "  │  Open WebUI:    ${CYAN}https://${server_ip}${NC}"
    echo -e "  │  API Swagger:   ${CYAN}https://${server_ip}/rag-docs${NC}"
    echo -e "  │  Health:        ${CYAN}https://${server_ip}/api/rag/health${NC}"
    echo -e ""
    echo -e "${BOLD}  🔑 Credenziali (salvate in .env):${NC}"
    echo -e "  │  File .env:     ${SCRIPT_DIR}/.env"
    echo -e "  │  Backup .env:   tenere sicuro, non committare su Git"
    echo -e ""
    echo -e "${BOLD}  ⚙️  Comandi utili:${NC}"
    echo -e "  │  make status     → Stato container"
    echo -e "  │  make logs       → Log in tempo reale"
    echo -e "  │  make health     → Healthcheck API"
    echo -e "  │  make test-chat  → Test query RAG"
    echo -e "  │  make backup     → Backup dati"
    echo -e "  │  make down       → Ferma lo stack"

    if [[ "${DEPLOY_MODE}" == "cpu" ]]; then
        echo -e ""
        echo -e "${BOLD}${YELLOW}  ⚠️  Modalità LITE (CPU-only):${NC}"
        echo -e "  │  La prima risposta potrebbe richiedere 60-180 secondi"
        echo -e "  │  Le risposte successive saranno più veloci"
        echo -e "  │  Monitor CPU: htop"
    else
        echo -e ""
        echo -e "${BOLD}  🎮 Modalità FULL (GPU):${NC}"
        echo -e "  │  Monitor GPU: make gpu-monitor"
        if [[ "${IS_WSL}" == "true" ]]; then
            echo -e ""
            echo -e "${BOLD}${YELLOW}  ⚠️  Sei su WSL — verifica GPU pass-through:${NC}"
            echo -e "${YELLOW}  │  Se i container non si avviano, usa: sudo ./install-cpu.sh${NC}"
            echo -e "${YELLOW}  │  Oppure consulta DEPLOYMENT_GUIDE.md sezione WSL${NC}"
        fi
    fi

    echo -e ""
    echo -e "${DIM}  Log installazione completo: ${LOG_FILE}${NC}"
    echo -e ""

    # Nota download modelli
    echo -e "${BOLD}${YELLOW}  📥 Download Modelli LLM:${NC}"
    echo -e "${YELLOW}  Il download di '${LLM_MODEL}' è in corso in background.${NC}"
    echo -e "${YELLOW}  Monitora il progresso con: make logs-init${NC}"
    echo -e "${YELLOW}  La WebUI sarà pienamente funzionale al termine del download.${NC}"
    echo -e ""
}

# ── Disinstallazione ──────────────────────────────────────────────────────────
uninstall() {
    log_section "Disinstallazione Private Corporate AI"

    echo -e "${RED}${BOLD}  ⚠️  ATTENZIONE: questa operazione rimuoverà:${NC}"
    echo -e "${RED}  - Tutti i container dello stack${NC}"
    echo -e "${RED}  - Tutti i volumi Docker (modelli LLM, indice Qdrant, documenti, chat history)${NC}"
    echo -e "${RED}  - Le immagini Docker custom${NC}"
    echo -e ""
    echo -ne "  ${BOLD}Digita 'ELIMINA' per confermare: ${NC}"
    read -r confirm

    if [[ "${confirm}" != "ELIMINA" ]]; then
        log_info "Disinstallazione annullata."
        exit 0
    fi

    cd "${SCRIPT_DIR}"
    # Ricostruisce l'array dal file .compose_cmd salvato dall'installer
    local -a compose_cmd
    if [[ -f .compose_cmd ]]; then
        read -ra compose_cmd < .compose_cmd
    else
        compose_cmd=(docker compose --env-file .env)
    fi

    "${compose_cmd[@]}" down -v --remove-orphans 2>&1 | tee -a "${LOG_FILE}"
    docker image rm "$(docker images 'private-corporate-ai*' -q)" 2>/dev/null || true

    log_ok "Stack rimosso completamente."
    log_info "I file di configurazione (.env, nginx/, rag_backend/) NON sono stati eliminati."
}

# ── Gestione Argomenti CLI ────────────────────────────────────────────────────
FORCED_MODE=""

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --gpu)      FORCED_MODE="gpu" ;;
            --cpu)      FORCED_MODE="cpu" ;;
            --uninstall) uninstall; exit 0 ;;
            --help|-h)  show_help; exit 0 ;;
            *)
                log_error "Argomento non riconosciuto: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# ── Main ──────────────────────────────────────────────────────────────────────
# ── Correzione proprietà file generati ───────────────────────────────────────
# Lo script gira con sudo: tutti i file creati appartengono a root.
# Questa funzione li restituisce all'utente reale che ha invocato sudo,
# in modo che possa leggerli e modificarli senza permessi elevati.
fix_ownership() {
    local real_user="${SUDO_USER:-}"

    # Nessun sudo (root diretto): niente da correggere
    if [[ -z "${real_user}" ]] || [[ "${real_user}" == "root" ]]; then
        return
    fi

    local real_group
    real_group=$(id -gn "${real_user}" 2>/dev/null || echo "${real_user}")

    log_step "Correzione proprietà file (owner: ${real_user})"

    # File singoli generati dallo script
    local files=(
        "${ENV_FILE}"
        "${SCRIPT_DIR}/.compose_cmd"
        "${SCRIPT_DIR}/install.log"
    )
    for f in "${files[@]}"; do
        [[ -f "${f}" ]] && chown "${real_user}:${real_group}" "${f}"
    done

    # Directory generate dallo script (ssl, log nginx)
    local dirs=(
        "${SCRIPT_DIR}/nginx/ssl"
    )
    for d in "${dirs[@]}"; do
        [[ -d "${d}" ]] && chown -R "${real_user}:${real_group}" "${d}"
    done

    # Mantieni i permessi restrittivi sulla chiave privata SSL
    [[ -f "${SCRIPT_DIR}/nginx/ssl/server.key" ]] && chmod 600 "${SCRIPT_DIR}/nginx/ssl/server.key"

    log_ok "Proprietà file corretta: ${real_user}:${real_group}"
    log_info "  .env, .compose_cmd, nginx/ssl/ → leggibili senza sudo"
}

main() {
    # Inizializza log
    echo "=== Install Log — $(date) ===" > "${LOG_FILE}"

    show_banner
    parse_args "$@"

    detect_hardware
    select_deploy_mode
    select_llm_model
    configure_advanced
    check_requirements

    # Riepilogo pre-installazione
    echo ""
    echo -e "${BOLD}  📋 Riepilogo installazione:${NC}"
    echo -e "  ┌─────────────────────────────────────────────┐"
    echo -e "  │  Modalità:     ${BOLD}${DEPLOY_MODE^^}${NC}"
    echo -e "  │  Modello LLM:  ${BOLD}${LLM_MODEL}${NC}"
    echo -e "  │  Embedding:    ${EMBEDDING_MODEL}"
    echo -e "  │  Hostname:     ${NGINX_HOST}"
    echo -e "  └─────────────────────────────────────────────┘"
    echo ""
    echo -ne "  ${BOLD}Procedere con l'installazione? [S/n]:${NC} "
    read -r proceed
    if [[ "${proceed}" =~ ^[nN]$ ]]; then
        log_info "Installazione annullata dall'utente."
        exit 0
    fi

    # Installazione
    install_docker
    install_nvidia_toolkit
    generate_ssl_certs
    generate_env_file
    patch_compose_for_cpu   # <── rimuove blocco GPU se DEPLOY_MODE=cpu
    build_and_start
    fix_ownership      # <── restituisce .env e altri file all'utente reale
    wait_for_healthy
    show_summary
}

main "$@"
