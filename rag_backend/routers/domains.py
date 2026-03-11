# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: API endpoints for domain (collection) management.
# =============================================================================

from typing import Optional
from fastapi import APIRouter, HTTPException
from qdrant_client.models import Filter, FieldCondition, MatchValue, PointIdsList

from config import settings
from core import rag
from schemas import DomainCreateRequest, MoveDomainRequest

router = APIRouter(prefix="/domains", tags=["Gestione Domini"])

@router.get("")
async def list_domains():
    client = rag.get_qdrant_client()
    collections = client.get_collections().collections
    domains = []
    for coll in collections:
        info = client.get_collection(coll.name)
        domains.append({
            "name": coll.name,
            "vectors_count": info.vectors_count,
            "points_count": info.points_count,
        })
    return domains

@router.post("")
async def create_domain(request: DomainCreateRequest):
    await rag.ensure_collection_exists(request.name)
    return {"name": request.name, "created": True}

@router.delete("/{domain_name}")
async def delete_domain(domain_name: str):
    if domain_name == settings.qdrant_collection_name:
        raise HTTPException(403, "Default collection cannot be deleted")
    client = rag.get_qdrant_client()
    client.delete_collection(domain_name)
    return {"deleted": True}

@router.put("/move/{doc_id}")
async def move_document_domain(doc_id: str, request: MoveDomainRequest):
    source = request.source_collection or settings.qdrant_collection_name
    target = request.target_collection
    client = rag.get_qdrant_client()
    
    await rag.ensure_collection_exists(target)
    
    filter_doc = Filter(should=[
        FieldCondition(key="doc_id", match=MatchValue(value=doc_id)),
        FieldCondition(key="metadata.doc_id", match=MatchValue(value=doc_id)),
    ])
    
    points, _ = client.scroll(collection_name=source, scroll_filter=filter_doc, limit=10000, with_vectors=True)
    if not points: raise HTTPException(404, "Doc non trovato")
    
    client.upsert(collection_name=target, points=points)
    client.delete(collection_name=source, points_selector=PointIdsList(points=[p.id for p in points]))
    return {"moved": len(points)}
