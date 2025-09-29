from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db import get_db
from app.models.user import User
from app.utils.auth import create_access_token, get_current_user
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])

# Request/Response Models
class PhoneRequest(BaseModel):
    phone_number: str
    
    @validator('phone_number')
    def validate_phone_number(cls, v):
        if not v or len(v) < 10:
            raise ValueError('Invalid phone number')
        return v

class OtpVerifyRequest(BaseModel):
    phone_number: str
    otp: str
    
    @validator('otp')
    def validate_otp(cls, v):
        if not v or len(v) != 6 or not v.isdigit():
            raise ValueError('OTP must be 6 digits')
        return v

class SignupRequest(BaseModel):
    phone_number: str
    name: str = None
    age_group: str = None
    gender: str = None
    occupation: str = None
    income_group: str = None
    
    @validator('phone_number')
    def validate_phone_number(cls, v):
        if not v or len(v) < 10:
            raise ValueError('Invalid phone number')
        return v

class LoginRequest(BaseModel):
    username: str  # phone_number
    password: str  # otp (for testing)

# Authentication Endpoints
@router.post("/send_otp")
async def send_otp_endpoint(user: PhoneRequest):
    """Send OTP to phone number"""
    try:
        logger.info(f"📱 Sending OTP to {user.phone_number}")
        
        # For testing, we'll simulate OTP sending
        # In production, integrate with SMS service
        # status = send_otp(user.phone_number)
        
        return {
            "message": "OTP sent successfully",
            "status": "pending",
            "phone_number": user.phone_number
        }
    except Exception as e:
        logger.error(f"Failed to send OTP: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to send OTP: {str(e)}")

@router.post("/verify_otp")
async def verify_otp_endpoint(otp_data: OtpVerifyRequest, db: AsyncSession = Depends(get_db)):
    """Verify OTP and return JWT token"""
    try:
        logger.info(f"🔍 Verifying OTP for {otp_data.phone_number}")
        
        # Check if user exists in database
        result = await db.execute(select(User).where(User.phone_number == otp_data.phone_number))
        user = result.scalars().first()
        
        if not user:
            logger.warning(f"User not found: {otp_data.phone_number}")
            raise HTTPException(status_code=404, detail="NEW_USER")
        
        # Generate JWT token
        token = create_access_token(data={"sub": otp_data.phone_number})
        logger.info(f"✅ Token generated for user: {otp_data.phone_number}")
        
        return {
            "access_token": token,
            "token_type": "bearer",
            "user": {
                "phone_number": user.phone_number,
                "name": user.name,
                "has_completed_profile": bool(user.name)
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"OTP verification failed: {e}")
        raise HTTPException(status_code=500, detail="OTP verification failed")

@router.post("/signup")
async def signup_endpoint(signup_data: SignupRequest, db: AsyncSession = Depends(get_db)):
    """Create new user account"""
    try:
        logger.info(f"👤 Creating account for {signup_data.phone_number}")
        
        # Check if user already exists
        result = await db.execute(select(User).where(User.phone_number == signup_data.phone_number))
        existing_user = result.scalars().first()
        
        if existing_user:
            logger.warning(f"User already exists: {signup_data.phone_number}")
            raise HTTPException(status_code=400, detail="User already exists")
        
        # Create new user
        new_user = User(
            phone_number=signup_data.phone_number,
            name=signup_data.name,
            age_group=signup_data.age_group,
            gender=signup_data.gender,
            occupation=signup_data.occupation,
            income_group=signup_data.income_group
        )
        
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)
        
        # Generate JWT token
        token = create_access_token(data={"sub": signup_data.phone_number})
        logger.info(f"✅ Account created and token generated for: {signup_data.phone_number}")
        
        return {
            "access_token": token,
            "token_type": "bearer",
            "user": {
                "phone_number": new_user.phone_number,
                "name": new_user.name,
                "has_completed_profile": True
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Signup failed: {e}")
        raise HTTPException(status_code=500, detail="Account creation failed")

@router.post("/login")
async def login_endpoint(login_data: LoginRequest, db: AsyncSession = Depends(get_db)):
    """Form-based login for OAuth2PasswordBearer compatibility"""
    try:
        logger.info(f"🔐 Login attempt for {login_data.username}")
        
        # For testing, accept any 6-digit password as valid OTP
        if len(login_data.password) != 6 or not login_data.password.isdigit():
            raise HTTPException(status_code=400, detail="Invalid OTP format")
        
        # Check if user exists
        result = await db.execute(select(User).where(User.phone_number == login_data.username))
        user = result.scalars().first()
        
        if not user:
            logger.warning(f"Login failed - user not found: {login_data.username}")
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        # Generate token
        token = create_access_token(data={"sub": login_data.username})
        logger.info(f"✅ Login successful for: {login_data.username}")
        
        return {
            "access_token": token,
            "token_type": "bearer",
            "user": {
                "phone_number": user.phone_number,
                "name": user.name,
                "has_completed_profile": bool(user.name)
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login failed: {e}")
        raise HTTPException(status_code=500, detail="Login failed")

@router.post("/refresh")
async def refresh_token(current_user: User = Depends(get_current_user)):
    """Refresh JWT token"""
    try:
        # Generate new token
        token = create_access_token(data={"sub": current_user.phone_number})
        
        return {
            "access_token": token,
            "token_type": "bearer"
        }
    except Exception as e:
        logger.error(f"Token refresh failed: {e}")
        raise HTTPException(status_code=500, detail="Token refresh failed")

@router.get("/me")
async def get_current_user_info(current_user: User = Depends(get_current_user)):
    """Get current user information"""
    return {
        "phone_number": current_user.phone_number,
        "name": current_user.name,
        "age_group": current_user.age_group,
        "gender": current_user.gender,
        "occupation": current_user.occupation,
        "income_group": current_user.income_group,
        "created_at": current_user.created_at
    }