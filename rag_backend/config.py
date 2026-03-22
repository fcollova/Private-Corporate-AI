# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Configuration settings loaded from environment variables and .env.
# =============================================================================

import os
from pathlib import Path
from pydantic import Field
from pydantic_settings import BaseSettings
from loguru import logger
from prometheus_client import Counter, Histogram

# =============================================================================
# CONFIGURAZIONE — Caricamento da variabili d'ambiente / .env
# =============================================================================

class Settings(BaseSettings):
    deploy_mode: str = Field(default="gpu", pattern="^(gpu|cpu)$")
    llm_model: str = Field(default="gemma2:9b")
    embedding_model: str = Field(default="nomic-embed-text")
    llm_temperature: float = Field(default=0.2, ge=0.0, le=1.0)
    llm_context_window: int = Field(default=4096, ge=512)
    ollama_base_url: str = Field(default="http://ollama:11434")
    ollama_num_parallel: int = Field(default=2, ge=1)
    request_timeout: int = Field(default=120, ge=30)
    qdrant_host: str = Field(default="qdrant")
    qdrant_port: int = Field(default=6333)
    qdrant_api_key: str = Field(default="changeme")
    qdrant_collection_name: str = Field(default="corporate_docs")
    chunk_size: int = Field(default=1000, ge=100)
    chunk_overlap: int = Field(default=200, ge=0)
    top_k_results: int = Field(default=5, ge=1, le=20)
    hybrid_search_enabled: bool = Field(default=True)
    upload_dir: str = Field(default="/app/uploads")
    data_dir: str = Field(default="/app/data")
    database_url: str = Field(default="sqlite+aiosqlite:////app/data/rag.db")
    web_workers: int = Field(default=2, ge=1)
    redis_url: str = Field(default="redis://redis:6379/0")
    embedding_cache_enabled: bool = Field(default=True)
    log_level: str = Field(default="INFO")

    # Profilo Cliente
    client_company: str = Field(default="Azienda S.r.l.")
    client_slug: str = Field(default="azienda")
    client_industry: str = Field(default="Generale")
    client_contact: str = Field(default="Amministratore")
    client_email: str = Field(default="admin@azienda.local")
    client_domain: str = Field(default="localhost")
    client_language: str = Field(default="italiano")
    client_lang_code: str = Field(default="it")
    client_theme_color: str = Field(default="#1A3A5C")
    client_theme_name: str = Field(default="blue")
    client_domains: str = Field(default="corporate_docs")

    @property
    def is_cpu_mode(self) -> bool:
        return self.deploy_mode.lower() == "cpu"

    @property
    def effective_timeout(self) -> int:
        return self.request_timeout if not self.is_cpu_mode else max(self.request_timeout, 300)

    class Config:
        extra = "ignore"

settings = Settings()

# Configura logger
logger.remove()
logger.add(
    sink=lambda msg: print(msg, end=""),
    level=settings.log_level,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> — <level>{message}</level>",
    colorize=True,
)

# =============================================================================
# METRICHE PROMETHEUS
# =============================================================================

DOCUMENTS_UPLOADED = Counter("rag_documents_uploaded_total", "Numero totale di documenti caricati", ["file_type"])
QUERY_REQUESTS = Counter("rag_query_requests_total", "Numero totale di query RAG ricevute")
QUERY_LATENCY = Histogram("rag_query_latency_seconds", "Latenza delle query RAG", buckets=[0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0])
CHUNKS_INDEXED = Counter("rag_chunks_indexed_total", "Numero totale di chunk indicizzati")
