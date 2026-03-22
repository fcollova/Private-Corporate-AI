# =============================================================================
# PROJECT: Private Corporate AI
# AUTHOR: Francesco Collovà
# LICENSE: Apache License 2.0
# YEAR: 2026
# DESCRIPTION: Database engine and session management.
# =============================================================================

import os
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from config import settings
from models import Base
from loguru import logger

# Crea il motore asincrono
engine = create_async_engine(
    settings.database_url,
    connect_args={"check_same_thread": False}, # Necessario per SQLite
)

# Crea il factory per le sessioni
SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

async def init_db():
    """Inizializza il database creando le tabelle se non esistono."""
    # Assicurati che la cartella data esista
    os.makedirs(settings.data_dir, exist_ok=True)
    
    async with engine.begin() as conn:
        # Per semplicità in Fase 1 creiamo tutto all'avvio
        # In produzione si userebbero le migrazioni (Alembic)
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database inizializzato con successo.")

async def get_db():
    """Dependency per ottenere una sessione del DB."""
    async with SessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()
