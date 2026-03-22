# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: API endpoints for document management (upload, list, delete, reindex).
# =============================================================================

import os
import uuid
import time
import hashlib
from pathlib import Path
from typing import Optional, List
from fastapi import APIRouter, UploadFile, File, HTTPException, BackgroundTasks, Depends, Query
from fastapi.responses import JSONResponse
import aiofiles
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, update
from qdrant_client.models import Filter, FieldCondition, MatchValue

from config import settings
from core import rag
from pipeline import process_document
from database import get_db
from models import Document, DocumentStatus

router = APIRouter(prefix="/documents", tags=["Documenti"])

async def calculate_hash(file_content: bytes) -> str:
    """Calcola l'hash SHA-256 del contenuto del file."""
    return hashlib.sha256(file_content).hexdigest()

@router.post("/upload")
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    collection_name: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    target_collection = collection_name or settings.qdrant_collection_name
    content = await file.read()
    file_hash = await calculate_hash(content)
    
    # 1. Verifica duplicati (Punto B)
    stmt = select(Document).where(Document.file_hash == file_hash, Document.collection_name == target_collection)
    result = await db.execute(stmt)
    existing_doc = result.scalar_one_or_none()
    
    if existing_doc:
        if existing_doc.status == DocumentStatus.COMPLETED:
            return {"message": "Documento già presente e indicizzato", "doc_id": existing_doc.doc_id, "status": "duplicate"}
        else:
            return {"message": f"Documento in stato {existing_doc.status}", "doc_id": existing_doc.doc_id, "status": "existing"}

    doc_id = str(uuid.uuid4())
    file_ext = Path(file.filename).suffix.lower()
    safe_filename = f"{doc_id}{file_ext}"
    file_path = os.path.join(settings.upload_dir, safe_filename)

    # 2. Salva il file fisico
    async with aiofiles.open(file_path, "wb") as f:
        await f.write(content)

    # 3. Registra nel DB (Punto A)
    new_doc = Document(
        doc_id=doc_id,
        filename=file.filename,
        file_type=file_ext,
        file_hash=file_hash,
        size_bytes=len(content),
        collection_name=target_collection,
        status=DocumentStatus.QUEUED
    )
    db.add(new_doc)
    await db.commit()

    # 4. Avvia pipeline asincrona (Punto C)
    background_tasks.add_task(process_document, file_path, file.filename, doc_id, target_collection)
    
    return {"message": "In elaborazione", "doc_id": doc_id, "status": "queued"}

@router.get("/list")
async def list_documents(
    collection_name: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    # Query SQL efficiente (Punto A)
    stmt = select(Document)
    if collection_name:
        stmt = stmt.where(Document.collection_name == collection_name)
    
    stmt = stmt.order_by(Document.created_at.desc())
    result = await db.execute(stmt)
    docs = result.scalars().all()
    
    return {"documents": [doc.to_dict() for doc in docs]}

@router.delete("/{doc_id}")
async def delete_document(
    doc_id: str, 
    collection_name: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    # 1. Trova il documento nel DB
    stmt = select(Document).where(Document.doc_id == doc_id)
    result = await db.execute(stmt)
    doc = result.scalar_one_or_none()
    
    if not doc:
        raise HTTPException(404, "Documento non trovato nel database")
        
    target_collection = collection_name or doc.collection_name
    
    # 2. Elimina da Qdrant
    client = rag.get_qdrant_client()
    filter_doc = Filter(should=[
        FieldCondition(key="doc_id", match=MatchValue(value=doc_id)),
        FieldCondition(key="metadata.doc_id", match=MatchValue(value=doc_id)),
    ])
    client.delete(collection_name=target_collection, points_selector=filter_doc)
    
    # 3. Elimina il file fisico
    file_path = os.path.join(settings.upload_dir, f"{doc.doc_id}{doc.file_type}")
    if os.path.exists(file_path):
        os.remove(file_path)
        
    # 4. Elimina dal DB
    await db.delete(doc)
    await db.commit()
    
    return {"deleted": True, "doc_id": doc_id}

@router.post("/batch-delete")
async def batch_delete_documents(
    doc_ids: List[str],
    collection_name: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """Eliminazione massiva di documenti (Punto E)."""
    deleted_ids = []
    for doc_id in doc_ids:
        try:
            await delete_document(doc_id, collection_name, db)
            deleted_ids.append(doc_id)
        except Exception as e:
            logger.warning(f"Errore eliminazione batch per {doc_id}: {e}")
            
    return {"deleted_count": len(deleted_ids), "ids": deleted_ids}

@router.post("/{doc_id}/reindex")
async def reindex_document(
    doc_id: str, 
    background_tasks: BackgroundTasks, 
    collection_name: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    stmt = select(Document).where(Document.doc_id == doc_id)
    result = await db.execute(stmt)
    doc = result.scalar_one_or_none()
    
    if not doc:
        raise HTTPException(404, "Documento non trovato")
    
    target_collection = collection_name or doc.collection_name
    file_path = os.path.join(settings.upload_dir, f"{doc.doc_id}{doc.file_type}")
    
    if not os.path.exists(file_path):
        raise HTTPException(410, "File fisico non presente sul server")
    
    # Reset stato nel DB
    doc.status = DocumentStatus.QUEUED
    doc.error_message = None
    doc.progress = 0
    await db.commit()
    
    # Elimina vecchi vettori e riavvia pipeline
    client = rag.get_qdrant_client()
    filter_doc = Filter(should=[
        FieldCondition(key="doc_id", match=MatchValue(value=doc_id)),
        FieldCondition(key="metadata.doc_id", match=MatchValue(value=doc_id)),
    ])
    client.delete(collection_name=target_collection, points_selector=filter_doc)
    
    background_tasks.add_task(process_document, file_path, doc.filename, doc_id, target_collection)
    return {"reindexing": True, "doc_id": doc_id}
