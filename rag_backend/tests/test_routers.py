import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch, AsyncMock
from main import app
from database import get_db
from models import SQLDocument, DocumentStatus

@pytest.fixture
def client(db_session):
    # Override della dependency get_db per usare il DB in-memory
    async def override_get_db():
        yield db_session
    
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()

def test_list_documents_empty(client):
    response = client.get("/api/documents/list")
    assert response.status_code == 200
    assert response.json() == {"documents": []}

@pytest.mark.asyncio
async def test_upload_duplicate_prevention(client, db_session):
    # 1. Inserisce un documento esistente nel DB
    existing = SQLDocument(
        doc_id="existing-123",
        filename="test.pdf",
        file_type=".pdf",
        file_hash="samehash",
        collection_name="corporate_docs",
        status=DocumentStatus.COMPLETED
    )
    db_session.add(existing)
    await db_session.commit()

    # 2. Tenta l'upload di un file con lo stesso contenuto (stesso hash)
    with patch("routers.documents.calculate_hash", return_value="samehash"):
        # Mock della lettura file per non dover creare un file reale
        files = {"file": ("test.pdf", b"fake content", "application/pdf")}
        response = client.post("/api/documents/upload", files=files)
        
        assert response.status_code == 200
        assert response.json()["status"] == "duplicate"
        assert "già presente" in response.json()["message"]

@pytest.mark.asyncio
async def test_chat_stream_endpoint(client):
    # Mock della pipeline streaming
    async def mock_stream(*args, **kwargs):
        yield {"type": "metadata", "sources": []}
        yield {"type": "content", "content": "Ciao"}
        yield {"type": "end", "latency": 0.1}

    with patch("routers.chat.rag_query_stream", side_effect=mock_stream):
        response = client.post("/api/chat/stream", json={"question": "Ciao"})
        assert response.status_code == 200
        assert "text/event-stream" in response.headers["content-type"]
        
        # Verifica il corpo dello stream
        content = response.text
        assert "data: " in content
        assert "Ciao" in content
