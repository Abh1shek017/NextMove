from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
import time
import logging

logger = logging.getLogger(__name__)

# Rate limiting storage (in production, use Redis)
request_counts = {}

class SecurityMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, max_requests_per_minute: int = 60):
        super().__init__(app)
        self.max_requests_per_minute = max_requests_per_minute

    async def dispatch(self, request: Request, call_next):
        # Rate limiting
        client_ip = request.client.host if request.client else "unknown"
        current_time = time.time()
        minute_key = f"{client_ip}:{int(current_time // 60)}"
        
        # Clean old entries
        for key in list(request_counts.keys()):
            if int(key.split(':')[1]) < int(current_time // 60) - 1:
                del request_counts[key]
        
        # Check rate limit
        if minute_key in request_counts:
            request_counts[minute_key] += 1
            if request_counts[minute_key] > self.max_requests_per_minute:
                logger.warning(f"Rate limit exceeded for IP: {client_ip}")
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Rate limit exceeded. Please try again later."}
                )
        else:
            request_counts[minute_key] = 1

        # Process request
        response = await call_next(request)
        
        # Add security headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        
        # Allow Swagger UI to load external resources for docs
        if request.url.path.startswith("/docs") or request.url.path.startswith("/redoc"):
            response.headers["Content-Security-Policy"] = "default-src 'self' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; img-src 'self' data: https:;"
        else:
            response.headers["Content-Security-Policy"] = "default-src 'self'"
        
        return response

# CORS security
from fastapi.middleware.cors import CORSMiddleware

def add_cors_security(app):
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["http://localhost:3000", "http://localhost:8080"],  # Add your frontend URLs
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "DELETE"],
        allow_headers=["*"],
    )