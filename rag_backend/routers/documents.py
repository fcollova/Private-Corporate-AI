import os
import uuid
from pathlib import Path
from typing import Optional
from fastapi import APIRouter, UploadFile, File, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse
import aiofiles
from qdrant_client.models import Filter, FieldCondition, MatchValue

from config import settings
from core import rag
from pipeline import process_document

router = APIRouter(prefix="/documents", tags=["Documenti"])

@router.post("/upload")
async def upload_document(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    collection_name: Optional[str] = None,
):
    doc_id = str(uuid.uuid4())
    safe_filename = f"{doc_id}_{file.filename}"
    file_path = os.path.join(settings.upload_dir, safe_filename)

    content = await file.read()
    async with aiofiles.open(file_path, "wb") as f:
        await f.write(content)

    background_tasks.add_task(process_document, file_path, file.filename, doc_id, collection_name)
    return {"message": "In elaborazione", "doc_id": doc_id}

@router.get("/list")
async def list_documents(collection_name: Optional[str] = None):
    target_collection = collection_name or settings.qdrant_collection_name
    client = rag.get_qdrant_client()
    
    points, _ = client.scroll(collection_name=target_collection, limit=10000, with_payload=True)
    
    docs_map = {}
    for point in points:
        meta = point.payload.get("metadata", point.payload)
        doc_id = meta.get("doc_id", "unknown")
        if doc_id not in docs_map:
            docs_map[doc_id] = {
                "doc_id": doc_id,
                "filename": meta.get("filename"),
                "file_type": meta.get("file_type"),
                "chunks_count": 0,
                "indexed_at": meta.get("indexed_at"),
            }
        docs_map[doc_id]["chunks_count"] += 1
        
    return {"documents": sorted(docs_map.values(), key=lambda x: x["indexed_at"] or "", reverse=True)}

@router.delete("/{doc_id}")
async def delete_document(doc_id: str, collection_name: Optional[str] = None):
    target_collection = collection_name or settings.qdrant_collection_name
    client = rag.get_qdrant_client()
    
    filter_doc = Filter(should=[
        FieldCondition(key="doc_id", match=MatchValue(value=doc_id)),
        FieldCondition(key="metadata.doc_id", match=MatchValue(value=doc_id)),
    ])
    
    points, _ = client.scroll(collection_name=target_collection, scroll_filter=filter_doc, limit=1)
    if not points:
        raise HTTPException(404, "Documento non trovato")
        
    client.delete(collection_name=target_collection, points_selector=filter_doc)
    return {"deleted": True, "doc_id": doc_id}

@router.post("/{doc_id}/reindex")
async def reindex_document(doc_id: str, background_tasks: BackgroundTasks, collection_name: Optional[str] = None):
    target_collection = collection_name or settings.qdrant_collection_name
    client = rag.get_qdrant_client()
    
    filter_doc = Filter(should=[
        FieldCondition(key="doc_id", match=MatchValue(value=doc_id)),
        FieldCondition(key="metadata.doc_id", match=MatchValue(value=doc_id)),
    ])
    
    points, _ = client.scroll(collection_name=target_collection, scroll_filter=filter_doc, limit=1)
    if not points: raise HTTPException(404, "Documento non trovato")
    
    meta = points[0].payload.get("metadata", points[0].payload)
    filename = meta.get("filename")
    file_path = os.path.join(settings.upload_dir, f"{doc_id}_{filename}")
    
    if not os.path.exists(file_path): raise HTTPException(410, "File non presente sul server")
    
    client.delete(collection_name=target_collection, points_selector=filter_doc)
    background_tasks.add_task(process_document, file_path, filename, doc_id, target_collection)
    return {"reindexing": True, "doc_id": doc_id}
