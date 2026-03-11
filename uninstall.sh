#!/usr/bin/env bash
# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Uninstallation script to remove the Docker stack, data, and configurations.
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_ok()    { echo -e "${GREEN}[  OK ]${NC}   $*"; }
log_info()  { echo -e "\033[0;34m[INFO]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[ WARN]${NC}   $*"; }
log_error() { echo -e "${RED}[ERROR]${NC}   $*"; }

# Ricostruisce l'array del comando compose da .compose_cmd o dal .env
# NOTA: usare sempre "${COMPOSE_CMD[@]}" dopo aver chiamato questa funzione.
build_compose_cmd() {
    if [[ -f "${SCRIPT_DIR}/.compose_cmd" ]]; then
        # Legge la riga salvata da install.sh e la espande in array
        read -ra COMPOSE_CMD < "${SCRIPT_DIR}/.compose_cmd"
    elif [[ -f "${SCRIPT_DIR}/.env" ]]; then
        # Autodetect dalla variabile DEPLOY_MODE nel .env
        local mode
        mode=$(grep "^DEPLOY_MODE=" "${SCRIPT_DIR}/.env" | cut -d= -f2 | tr -d '[:space:]')
        if [[ "${mode}" == "cpu" ]]; then
            COMPOSE_CMD=(docker compose
                -f docker-compose.yaml
                -f docker-compose.lite.yaml
                --env-file .env)
        else
            COMPOSE_CMD=(docker compose --env-file .env)
        fi
    else
        COMPOSE_CMD=(docker compose --env-file .env)
    fi
}

# ── Banner ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${RED}  ╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}  ║   Private Corporate AI — Disinstallazione    ║${NC}"
echo -e "${BOLD}${RED}  ╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Argomenti ──────────────────────────────────────────────────────────────────
MODE="${1:-interactive}"

case "${1:-}" in
    --all)    MODE="all" ;;
    --soft)   MODE="soft" ;;
    --help|-h)
        cat << EOF
UTILIZZO:
    sudo ./uninstall.sh            Interattivo (scelta del livello)
    sudo ./uninstall.sh --soft     Solo container (dati conservati)
    sudo ./uninstall.sh --all      Rimozione totale (container + volumi + file)

LIVELLI DI RIMOZIONE:
    soft   Ferma e rimuove i container Docker. Conserva volumi (dati),
           file di configurazione (.env, nginx/ssl, rag_backend/).
           Rieseguire install.sh per ripristinare.

    all    Rimozione completa: container, volumi Docker (tutti i dati
           inclusi modelli LLM, indice Qdrant, documenti, chat history)
           e file di configurazione generati.
           NON eliminabile automaticamente: i file sorgente del progetto.
EOF
        exit 0
        ;;
esac

cd "${SCRIPT_DIR}"

# ── Scelta interattiva ─────────────────────────────────────────────────────────
if [[ "${MODE}" == "interactive" ]]; then
    echo -e "${BOLD}  Scegli il livello di disinstallazione:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${BOLD}Soft${NC} — Ferma i container, conserva tutti i dati"
    echo -e "     ${DIM}Mantiene: modelli LLM, indice vettoriale, documenti, chat history${NC}"
    echo -e "     ${DIM}Riavvio rapido con: make up-gpu / make up-lite${NC}"
    echo ""
    echo -e "  ${RED}2)${NC} ${BOLD}Completa${NC} — Rimuove container + volumi Docker (cancella TUTTI i dati)"
    echo -e "     ${DIM}Elimina: modelli LLM (si riscaricano), indice Qdrant, documenti, chat${NC}"
    echo -e "     ${DIM}Mantiene: file sorgente, .env, certificati SSL${NC}"
    echo ""
    echo -e "  ${RED}3)${NC} ${BOLD}Totale${NC} — Rimuove tutto inclusi file di configurazione generati"
    echo -e "     ${DIM}Elimina: tutto quanto sopra + .env, nginx/ssl/, .compose_cmd${NC}"
    echo ""
    echo -ne "  ${BOLD}Scelta [1/2/3, default=1]:${NC} "
    read -r choice

    case "${choice:-1}" in
        1) MODE="soft" ;;
        2) MODE="all" ;;
        3) MODE="total" ;;
        *) MODE="soft" ;;
    esac
fi

# ── Conferma ──────────────────────────────────────────────────────────────────
case "${MODE}" in
    soft)
        echo ""
        echo -e "${YELLOW}  Operazione: Ferma i container (dati conservati)${NC}"
        echo -ne "  Confermi? [s/N]: "
        read -r confirm
        [[ ! "${confirm}" =~ ^[sS]$ ]] && { log_info "Annullato."; exit 0; }
        ;;
    all|total)
        echo ""
        echo -e "${RED}  ⚠️  ATTENZIONE: questa operazione è IRREVERSIBILE${NC}"
        echo -e "${RED}  Verranno eliminati:${NC}"
        echo -e "${RED}  - Tutti i modelli LLM scaricati (saranno da riscaricare)${NC}"
        echo -e "${RED}  - L'intero indice vettoriale Qdrant (documenti da reindicizzare)${NC}"
        echo -e "${RED}  - I documenti caricati dagli utenti${NC}"
        echo -e "${RED}  - La cronologia chat di Open WebUI${NC}"
        [[ "${MODE}" == "total" ]] && echo -e "${RED}  - File .env e certificati SSL${NC}"
        echo ""
        echo -ne "  Digita '${RED}ELIMINA${NC}' per confermare: "
        read -r confirm
        [[ "${confirm}" != "ELIMINA" ]] && { log_info "Annullato."; exit 0; }
        ;;
esac

# ── Esecuzione ─────────────────────────────────────────────────────────────────
# Ricostruisce l'array (mai usare stringa: i -f flag causano "command not found")
build_compose_cmd
log_info "Comando compose: ${COMPOSE_CMD[*]}"
echo ""

case "${MODE}" in
    soft)
        log_info "Arresto container..."
        "${COMPOSE_CMD[@]}" down 2>/dev/null || true
        log_ok "Container fermati. I dati nei volumi sono conservati."
        log_info "Per riavviare: make up-gpu  oppure  make up-lite"
        ;;

    all)
        log_info "Rimozione container e volumi..."
        "${COMPOSE_CMD[@]}" down -v --remove-orphans 2>/dev/null || true

        # Rimuovi immagini custom buildate
        log_info "Rimozione immagini Docker custom..."
        docker image rm "private-corporate-ai-rag_backend" 2>/dev/null || true
        docker image ls | grep "corporate-ai" | awk '{print $3}' | xargs docker image rm 2>/dev/null || true

        log_ok "Container, volumi e immagini rimossi."
        log_info "I file di configurazione (.env, nginx/, rag_backend/) sono conservati."
        ;;

    total)
        log_info "Rimozione completa in corso..."
        "${COMPOSE_CMD[@]}" down -v --remove-orphans 2>/dev/null || true
        docker image rm "private-corporate-ai-rag_backend" 2>/dev/null || true

        # Rimuovi file generati (NON i sorgenti del progetto)
        log_info "Rimozione file di configurazione generati..."
        [[ -f "${SCRIPT_DIR}/.env" ]] && rm -f "${SCRIPT_DIR}/.env" && log_info "  Rimosso: .env"
        [[ -d "${SCRIPT_DIR}/nginx/ssl" ]] && rm -rf "${SCRIPT_DIR}/nginx/ssl" && log_info "  Rimossa: nginx/ssl/"
        [[ -f "${SCRIPT_DIR}/.compose_cmd" ]] && rm -f "${SCRIPT_DIR}/.compose_cmd"
        [[ -f "${SCRIPT_DIR}/install.log" ]] && rm -f "${SCRIPT_DIR}/install.log"
        # Rimuovi backup .env
        rm -f "${SCRIPT_DIR}"/.env.backup.* 2>/dev/null || true

        log_ok "Rimozione totale completata."
        log_info "I file sorgente del progetto sono conservati."
        log_info "Per reinstallare: sudo ./install.sh"
        ;;
esac

echo ""
log_ok "Disinstallazione completata."
echo ""
