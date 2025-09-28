# app/routers/auth.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db import get_db
from app.models.user import User
from app.schemas import UserCreate, Token
from app.utils.auth import get_password_hash, create_access_token

router = APIRouter(prefix="/auth", tags=["auth"])
import logging

logging.basicConfig(level=logging.DEBUG)

@router.post("/signup", response_model=Token)
async def signup(user: UserCreate, db: AsyncSession = Depends(get_db)):
    try:
        result = await db.execute(select(User).where(User.phone_number == user.phone_number))
        db_user = result.scalars().first()
        
        if db_user:
            access_token = create_access_token(data={"sub": user.phone_number})
            return {"access_token": access_token, "token_type": "bearer"}
        
        db_user = User(**user.dict())
        db.add(db_user)
        await db.commit()
        await db.refresh(db_user)
        
        access_token = create_access_token(data={"sub": user.phone_number})
        return {"access_token": access_token, "token_type": "bearer"}
    except Exception as e:
        logging.error("Signup error: %s", str(e))
        raise
@router.post("/login", response_model=Token)
async def login(user: UserCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.phone_number == user.phone_number))
    db_user = result.scalars().first()
    
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found. Please sign up first.",
        )
    
    access_token = create_access_token(data={"sub": user.phone_number})
    return {"access_token": access_token, "token_type": "bearer"}