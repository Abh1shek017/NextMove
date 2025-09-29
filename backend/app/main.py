from fastapi import FastAPI
from app.db import engine
from app.database.base import Base
from app.models.ml_training import MLTrainingData
from app.models.trip_detection_training import TripDetectionTraining
# Import models to register them
from app.models.user import User
from app.models.trip import Trip
from app.models.gps_log import GPSLog

# Import routers
from app.routers import trips, gps, auth, ml

# Import security middleware
from app.middleware.security import SecurityMiddleware, add_cors_security

app = FastAPI(
    title="NextMove API",
    description="Secure transportation tracking API with user authentication",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Add security middleware
app.add_middleware(SecurityMiddleware, max_requests_per_minute=60)
add_cors_security(app)

app.include_router(auth.router)
app.include_router(trips.router)
app.include_router(gps.router)
app.include_router(ml.router)

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

@app.get("/")
async def root():
    return {"message": "NextMove API"}

# Admin endpoint removed for security - was unprotected and dangerous
# If needed, implement with proper admin authentication