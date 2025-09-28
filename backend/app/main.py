from fastapi import FastAPI
from app.db import engine
from app.database.base import Base
from app.models.ml_training import MLTrainingData
# Import models to register them
from app.models.user import User
from app.models.trip import Trip
from app.models.gps_log import GPSLog

# Import routers
from app.routers import trips, gps

app = FastAPI(title="NextMove API (No Auth)")

app.include_router(trips.router)
app.include_router(gps.router)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

@app.get("/")
async def root():
    return {"message": "NextMove API - No Auth Mode"}