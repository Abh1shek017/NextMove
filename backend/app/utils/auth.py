from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db import get_db
from app.models.user import User
from app.config import settings
import logging

logger = logging.getLogger(__name__)

# Security scheme for FastAPI docs
security = HTTPBearer(auto_error=False)

def create_access_token(data: dict):
    """Generate a JWT access token with phone number as sub"""
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.access_token_expire_minutes
    )
    to_encode.update({"exp": expire})

    if "sub" not in to_encode:
        raise ValueError("JWT payload must include 'sub' (phone_number)")

    encoded_jwt = jwt.encode(
        to_encode, settings.secret_key, algorithm=settings.algorithm
    )
    return encoded_jwt

def verify_token(token: str) -> dict:
    """Verify JWT token and return payload"""
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        return payload
    except JWTError as e:
        logger.error(f"JWT verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_current_user(
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    """Get current authenticated user"""
    logger.info(f"🔍 get_current_user called")
    
    # Extract Authorization header manually
    auth_header = request.headers.get("Authorization")
    logger.info(f"🔍 Authorization header: {auth_header}")
    
    if not auth_header:
        logger.error("❌ No Authorization header provided")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not auth_header.startswith("Bearer "):
        logger.error("❌ Invalid Authorization header format")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authorization header format",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    token = auth_header[7:]  # Remove "Bearer " prefix
    logger.info(f"🔍 Token extracted: {token[:20]}...")

    try:
        # Verify token
        payload = verify_token(token)
        phone_number: str = payload.get("sub")
        
        if phone_number is None:
            logger.error("❌ No phone number in token")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Get user from database
        result = await db.execute(select(User).where(User.phone_number == phone_number))
        user = result.scalars().first()
        
        if user is None:
            logger.error(f"❌ User not found for phone: {phone_number}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        logger.info(f"✅ User authenticated: {user.phone_number}")
        return user

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed",
            headers={"WWW-Authenticate": "Bearer"},
        )

# Optional authentication for some endpoints
async def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
):
    """Get current user if authenticated, otherwise return None"""
    if not credentials:
        return None
    
    try:
        return await get_current_user(credentials, db)
    except HTTPException:
        return None

# Admin authentication (for future use)
async def get_admin_user(
    current_user: User = Depends(get_current_user)
):
    """Get current user and verify admin privileges"""
    # For now, all users are considered admins
    # In production, add proper role-based access control
    if not current_user:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return current_user