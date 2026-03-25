# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: API endpoints for indexing management and settings.
# =============================================================================

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime

from database import get_db
from models import IndexingSettings
from config import settings
from core import rag

router = APIRouter(prefix="/indexing", tags=["Indexing Management"])

@router.get("/settings")
async def get_indexing_settings(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(IndexingSettings).limit(1))
    db_settings = result.scalar_one_or_none()
    
    if not db_settings:
        # Ritorna i default dal file config se non presenti nel DB
        return {
            "chunk_size": settings.chunk_size,
            "chunk_overlap": settings.chunk_overlap,
            "top_k_results": settings.top_k_results,
            "hybrid_search_enabled": settings.hybrid_search_enabled,
            "llm_temperature": settings.llm_temperature,
            "is_default": True
        }
    return db_settings.to_dict()

@router.put("/settings")
async def update_indexing_settings(new_settings: dict, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(IndexingSettings).limit(1))
    db_settings = result.scalar_one_or_none()
    
    if not db_settings:
        db_settings = IndexingSettings()
        db.add(db_settings)
    
    db_settings.chunk_size = new_settings.get("chunk_size", db_settings.chunk_size)
    db_settings.chunk_overlap = new_settings.get("chunk_overlap", db_settings.chunk_overlap)
    db_settings.top_k_results = new_settings.get("top_k_results", db_settings.top_k_results)
    db_settings.hybrid_search_enabled = new_settings.get("hybrid_search_enabled", db_settings.hybrid_search_enabled)
    db_settings.llm_temperature = new_settings.get("llm_temperature", db_settings.llm_temperature)
    
    await db.commit()
    return db_settings.to_dict()

@router.get("/stats")
async def get_indexing_stats():
    """Restituisce statistiche dettagliate sullo stato di Qdrant per il monitoraggio."""
    try:
        client = rag.get_qdrant_client()
        collections = client.get_collections().collections
        
        total_vectors = 0
        total_points = 0
        domains_info = []
        
        for coll in collections:
            info = client.get_collection(coll.name)
            # Se vectors_count è None o 0, usiamo points_count che è più affidabile
            v_count = info.vectors_count if info.vectors_count is not None else info.points_count
            total_vectors += v_count or 0
            total_points += info.points_count or 0
            
            # Estrazione parametri di configurazione della collezione
            config = info.config
            domains_info.append({
                "name": coll.name,
                "status": info.status,
                "optimizer_status": info.optimizer_status,
                "vectors_count": v_count,
                "points_count": info.points_count,
                "segments_count": info.segments_count,
                "config": {
                    "vector_size": config.params.vectors.size if hasattr(config.params.vectors, 'size') else "N/A",
                    "distance": config.params.vectors.distance if hasattr(config.params.vectors, 'distance') else "N/A",
                    "hnsw_config": config.hnsw_config.__dict__ if hasattr(config, 'hnsw_config') else {},
                    "quantization_config": config.quantization_config if hasattr(config, 'quantization_config') else None
                }
            })
            
        # Prova a recuperare info di sistema se disponibili (telemetria)
        # Nota: richiede permessi admin su Qdrant, facciamo un fallback sicuro
        system_info = {"version": "Unknown", "uptime": "N/A"}
        try:
            # Alcune versioni di qdrant-client espongono info via telemetria
            telemetry = client.get_telemetry()
            if hasattr(telemetry, 'app'):
                system_info["version"] = getattr(telemetry.app, 'version', "Unknown")
        except: pass

        return {
            "system": system_info,
            "total_collections": len(collections),
            "total_vectors": total_vectors,
            "total_points": total_points,
            "collections_detail": domains_info,
            "database_engine": "Qdrant Vector DB",
            "deploy_mode": settings.deploy_mode
        }
    except Exception as e:
        logger.error(f"Errore recupero statistiche Qdrant: {e}")
        raise HTTPException(500, detail=str(e))

@router.post("/test-query")
async def test_indexing_query(request: dict):
    """Esegue una ricerca su Qdrant e restituisce i chunk senza passare dall'LLM."""
    query = request.get("query")
    collection = request.get("collection") or settings.qdrant_collection_name
    top_k = request.get("top_k", settings.top_k_results)
    
    if not query:
        raise HTTPException(400, "Query string is required")
    
    client = rag.get_qdrant_client()
    embeddings = rag.get_embeddings()
    
    query_vector = await asyncio.to_thread(embeddings.embed_query, query)
    
    results = client.search(
        collection_name=collection,
        query_vector=query_vector,
        limit=top_k,
        with_payload=True
    )
    
    chunks = []
    for res in results:
        chunks.append({
            "score": res.score,
            "text": res.payload.get("page_content", ""),
            "metadata": res.payload.get("metadata", {})
        })
        
    return {"query": query, "collection": collection, "results": chunks}

import asyncio # Necessario per asyncio.to_thread nel router
