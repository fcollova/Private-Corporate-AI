# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Dockerfile for the RAG Backend (FastAPI application).
# =============================================================================

# Base: Python 3.11 slim (Debian Bookworm)
FROM python:3.11-slim

# Impostazioni ambientali
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV TZ=Europe/Rome

WORKDIR /app

# Dipendenze sistema (cacheable - cambiano raramente)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Definizione argomenti build (Sposta dopo le dipendenze sistema)
ARG INSTALL_MODE=gpu

# Copia solo requirements.txt per sfruttare la cache delle dipendenze
COPY requirements.txt .

# Installazione dipendenze Python con caching intelligente
RUN pip install --no-cache-dir --default-timeout=100 -r requirements.txt

# Copia il resto del codice solo alla fine (così i cambi al codice non rifanno il pip install)
COPY . .

# Directory upload
RUN mkdir -p uploads

EXPOSE 8000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/api/rag/health || exit 1

# Avvio
CMD ["python", "main.py"]
