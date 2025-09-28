# backend/app/main.py
from fastapi import FastAPI
from app.routers import auth
from app.config import settings
from app.db import engine
from app.database.base import Base

# ✅ CORRECT: All arguments are keyword-based
app = FastAPI(
    title="NextMove API",
    description="Transport mode prediction for urban mobility",
    version="0.1.0"
)

app.include_router(auth.router)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

@app.get("/")
async def root():
    return {"message": "Welcome to NextMove!"}

@app.get("/health")
async def health_check():
    return {"status": "OK", "db_url": settings.database_url}