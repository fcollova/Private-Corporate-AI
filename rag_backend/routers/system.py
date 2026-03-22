# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: API endpoints for system health, metrics, and client information.
# =============================================================================

import os
import shutil
import httpx
from fastapi import APIRouter, Depends, HTTPException
from starlette.responses import Response
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import delete
from loguru import logger

from config import settings
from schemas import HealthResponse
from core import rag
from database import get_db
from models import Document

router = APIRouter(tags=["Sistema"])

@router.post("/wipe")
async def wipe_system(db: AsyncSession = Depends(get_db)):
    """Pulisce completamente il sistema RAG (Operazione distruttiva)."""
    try:
        # 1. Svuota il Database SQL
        await db.execute(delete(Document))
        await db.commit()
        
        # 2. Elimina collezioni da Qdrant
        client = rag.get_qdrant_client()
        collections = client.get_collections().collections
        for coll in collections:
            client.delete_collection(coll.name)
            
        # 3. Svuota cartella uploads
        if os.path.exists(settings.upload_dir):
            for filename in os.listdir(settings.upload_dir):
                file_path = os.path.join(settings.upload_dir, filename)
                try:
                    if os.path.isfile(file_path) or os.path.islink(file_path):
                        os.unlink(file_path)
                    elif os.path.isdir(file_path):
                        shutil.rmtree(file_path)
                except Exception as e:
                    logger.warning(f"Errore eliminazione {file_path}: {e}")
        
        # 4. Svuota Redis (se abilitato)
        if settings.embedding_cache_enabled:
            import redis
            r = redis.from_url(settings.redis_url)
            r.flushall()
            
        return {"message": "Sistema ripulito completamente", "status": "success"}
    except Exception as e:
        logger.error(f"Errore durante il wipe di sistema: {e}")
        raise HTTPException(500, detail=str(e))

@router.get("/health", response_model=HealthResponse)
async def health_check():
    ollama_ok, qdrant_ok = False, False
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{settings.ollama_base_url}/api/version")
            ollama_ok = resp.status_code == 200
    except: pass
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"http://{settings.qdrant_host}:{settings.qdrant_port}/healthz")
            qdrant_ok = resp.status_code == 200
    except: pass
    
    return HealthResponse(
        status="healthy" if ollama_ok and qdrant_ok else "degraded",
        deploy_mode=settings.deploy_mode,
        ollama_connected=ollama_ok,
        qdrant_connected=qdrant_ok,
        model_loaded=settings.llm_model,
        embedding_model=settings.embedding_model,
        collection_name=settings.qdrant_collection_name,
        timeout_seconds=settings.effective_timeout,
    )

@router.get("/metrics")
async def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@router.get("/client/info")
async def get_client_info():
    return {
        "company": settings.client_company,
        "theme_color": settings.client_theme_color,
    }

@router.get("/models/available")
async def list_available_models():
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(f"{settings.ollama_base_url}/api/tags")
        data = resp.json()
    return {"models": data.get("models", []), "current": settings.llm_model}
