# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: API endpoints for RAG chat and OpenAI compatibility layer.
# =============================================================================

import uuid
import time
import httpx
from fastapi import APIRouter, HTTPException
from schemas import ChatRequest, ChatResponse, OpenAIChatRequest
from pipeline import rag_query
from config import settings

router = APIRouter(tags=["Chat"])

@router.post("/chat", response_model=ChatResponse)
async def chat_with_docs(request: ChatRequest):
    result = await rag_query(
        question=request.question,
        collection_name=request.collection_name,
        top_k=request.top_k,
        model_name=request.model,
    )
    return ChatResponse(**result)

@router.post("/v1/chat/completions")
async def openai_compatible_chat(request: OpenAIChatRequest):
    user_msgs = [m for m in request.messages if m.role == "user"]
    if not user_msgs: raise HTTPException(400, "No user message")
    
    result = await rag_query(question=user_msgs[-1].content)
    
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:8]}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": result["model_used"],
        "choices": [{"index": 0, "message": {"role": "assistant", "content": result["answer"]}, "finish_reason": "stop"}],
        "rag_metadata": result
    }

@router.get("/v1/models")
async def openai_list_models():
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(f"{settings.ollama_base_url}/api/tags")
            ollama_models = resp.json().get("models", [])
    except: ollama_models = []

    rag_model = {"id": "private-rag", "object": "model", "owned_by": "private-corporate-ai"}
    chat_models = [{"id": m["name"], "object": "model", "owned_by": "ollama"} for m in ollama_models]
    
    return {"object": "list", "data": [rag_model] + chat_models}
