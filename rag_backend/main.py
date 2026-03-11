# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Main FastAPI application entry point and router inclusion.
# =============================================================================

from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from loguru import logger

from config import settings
from routers import system, documents, domains, chat

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("═" * 60)
    logger.info("  Private Corporate AI — RAG Backend (MODULAR)")
    logger.info(f"  Modalita': {settings.deploy_mode}")
    logger.info("═" * 60)
    
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)
    yield
    logger.info("Shutdown RAG Backend")

app = FastAPI(
    title="Private Corporate AI — RAG Backend",
    version="1.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclusione Router
app.include_router(system.router, prefix="/api")
app.include_router(documents.router, prefix="/api")
app.include_router(domains.router, prefix="/api")
app.include_router(chat.router, prefix="/api")

# OpenAI compatible routes have their own prefix handling
app.include_router(chat.router)

if __name__ == "__main__":
    import uvicorn
    # Siamo gia' dentro la cartella rag_backend nel container (/app)
    # Rimuoviamo il prefisso del modulo per evitare ModuleNotFoundError
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
