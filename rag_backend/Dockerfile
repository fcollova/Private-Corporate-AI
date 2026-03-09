# =============================================================================
# PRIVATE CORPORATE AI — Dockerfile RAG Backend
# Base: Python 3.11 slim (Debian Bookworm)
# =============================================================================

FROM python:3.11-slim-bookworm

# Metadati immagine
LABEL maintainer="Private Corporate AI"
LABEL description="RAG Backend - FastAPI + LangChain + Qdrant"
LABEL version="1.0.0"

# Variabili d'ambiente per Python
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Installa dipendenze di sistema necessarie per i document loaders
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Necessari per pypdf e unstructured
    libmagic1 \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-ita \
    tesseract-ocr-eng \
    # Necessari per python-docx
    libxml2-dev \
    libxslt1-dev \
    # Networking
    curl \
    # Cleanup
    && rm -rf /var/lib/apt/lists/*

# Crea utente non-root per sicurezza
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

# Directory di lavoro
WORKDIR /app

# Copia e installa dipendenze Python (layer cacheable separato)
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Crea directory per i file caricati
RUN mkdir -p /app/uploads && chown appuser:appgroup /app/uploads

# Copia il codice applicativo
COPY --chown=appuser:appgroup . .

# Cambia all'utente non-root
USER appuser

# Health check interno
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD curl -f http://localhost:8000/api/health || exit 1

# Porta esposta
EXPOSE 8000

# Avvio con Uvicorn (produzione: workers multipli)
CMD ["uvicorn", "app:app", \
     "--host", "0.0.0.0", \
     "--port", "8000", \
     "--workers", "2", \
     "--log-level", "info", \
     "--access-log"]
