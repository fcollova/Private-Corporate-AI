# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: SQLAlchemy models for the metadata store.
# =============================================================================

from datetime import datetime
from typing import Optional
from sqlalchemy import String, Integer, DateTime, BigInteger, Enum as SQLEnum
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
import enum

class Base(DeclarativeBase):
    pass

class DocumentStatus(str, enum.Enum):
    QUEUED = "queued"
    EXTRACTING = "extracting"
    CONTEXTUALIZING = "contextualizing"
    EMBEDDING = "embedding"
    COMPLETED = "completed"
    FAILED = "failed"

class Document(Base):
    __tablename__ = "documents"

    id: Mapped[int] = mapped_column(primary_key=True)
    doc_id: Mapped[str] = mapped_column(String(36), unique=True, index=True)
    filename: Mapped[str] = mapped_column(String(255))
    file_type: Mapped[str] = mapped_column(String(10))
    file_hash: Mapped[str] = mapped_column(String(64), index=True)  # SHA-256
    size_bytes: Mapped[int] = mapped_column(BigInteger, default=0)
    
    # State tracking
    status: Mapped[DocumentStatus] = mapped_column(
        SQLEnum(DocumentStatus), default=DocumentStatus.QUEUED, index=True
    )
    progress: Mapped[int] = mapped_column(Integer, default=0)  # 0-100%
    error_message: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    
    # Corporate Metadata (Fase 1 - Point 4)
    collection_name: Mapped[str] = mapped_column(String(64), index=True)
    owner_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    department_id: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    access_level: Mapped[str] = mapped_column(String(20), default="confidential") # public, internal, confidential, restricted
    
    # Timestamps
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    indexed_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

    def to_dict(self):
        return {
            "doc_id": self.doc_id,
            "filename": self.filename,
            "file_type": self.file_type,
            "status": self.status,
            "progress": self.progress,
            "error": self.error_message,
            "collection_name": self.collection_name,
            "owner_id": self.owner_id,
            "department_id": self.department_id,
            "access_level": self.access_level,
            "size_bytes": self.size_bytes,
            "indexed_at": self.indexed_at.isoformat() if self.indexed_at else None,
            "created_at": self.created_at.isoformat()
        }

class IndexingSettings(Base):
    __tablename__ = "indexing_settings"

    id: Mapped[int] = mapped_column(primary_key=True)
    chunk_size: Mapped[int] = mapped_column(Integer, default=1000)
    chunk_overlap: Mapped[int] = mapped_column(Integer, default=200)
    top_k_results: Mapped[int] = mapped_column(Integer, default=5)
    hybrid_search_enabled: Mapped[bool] = mapped_column(Integer, default=1) # Boolean as int for safety
    llm_temperature: Mapped[float] = mapped_column(Integer, default=0.2)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    def to_dict(self):
        return {
            "chunk_size": self.chunk_size,
            "chunk_overlap": self.chunk_overlap,
            "top_k_results": self.top_k_results,
            "hybrid_search_enabled": bool(self.hybrid_search_enabled),
            "llm_temperature": float(self.llm_temperature),
            "updated_at": self.updated_at.isoformat()
        }

