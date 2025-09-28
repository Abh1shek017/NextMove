# backend/app/main.py
from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi
from app.config import settings
from app.db import engine
from app.database.base import Base

# Import models to register them
from app.models.user import User
from app.models.trip import Trip

# Import routers
from app.routers import auth
from app.routers import trips

def create_app() -> FastAPI:
    app = FastAPI(
        title="NextMove API",
        description="Transport mode prediction for urban mobility",
        version="0.1.0",
        # Disable default docs security (we'll override it)
        openapi_url="/openapi.json",
        docs_url="/docs",
        redoc_url="/redoc"
    )

    app.include_router(auth.router)
    app.include_router(trips.router)

    @app.on_event("startup")
    async def startup():
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    @app.get("/")
    async def root():
        return {"message": "Welcome to NextMove!"}

    @app.get("/health")
    async def health_check():
        return {"status": "OK"}

    # ✅ CUSTOM OPENAPI: Use simple Bearer token
    def custom_openapi():
        if app.openapi_schema:
            return app.openapi_schema
        openapi_schema = get_openapi(
            title=app.title,
            version=app.version,
            description=app.description,
            routes=app.routes,
        )
        # Remove OAuth2 password flow, add simple Bearer
        openapi_schema["components"]["securitySchemes"] = {
            "Bearer": {
                "type": "http",
                "scheme": "bearer",
                "bearerFormat": "JWT",
                "description": "Enter your JWT token (from /auth/signup or /auth/login)"
            }
        }
        # Apply globally
        openapi_schema["security"] = [{"Bearer": []}]
        app.openapi_schema = openapi_schema
        return openapi_schema

    app.openapi = custom_openapi
    return app

app = create_app()