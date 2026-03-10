from typing import Optional, List
from pydantic import BaseModel, Field

# =============================================================================
# MODELLI PYDANTIC — Request/Response
# =============================================================================

class ChatRequest(BaseModel):
    question: str = Field(..., min_length=1, max_length=2000)
    collection_name: Optional[str] = None
    top_k: Optional[int] = Field(default=None, ge=1, le=20)
    model: Optional[str] = None

class ChatResponse(BaseModel):
    answer: str
    sources: List[dict]
    model_used: str
    chunks_retrieved: int
    latency_seconds: float

class DocumentInfo(BaseModel):
    doc_id: str
    filename: str
    file_type: str
    chunks_count: int
    indexed_at: str
    size_bytes: Optional[int] = 0

class DomainCreateRequest(BaseModel):
    name: str = Field(..., min_length=2, max_length=64, pattern=r'^[a-zA-Z0-9_\-]+$')

class MoveDomainRequest(BaseModel):
    target_collection: str
    source_collection: Optional[str] = None

class HealthResponse(BaseModel):
    status: str
    deploy_mode: str
    ollama_connected: bool
    qdrant_connected: bool
    model_loaded: str
    embedding_model: str
    collection_name: str
    timeout_seconds: int
    version: str = "1.0.0"

# OpenAI Compatibility
class OpenAIMessage(BaseModel):
    role: str
    content: str

class OpenAIChatRequest(BaseModel):
    model: str = "local-rag"
    messages: List[OpenAIMessage]
    stream: bool = False
