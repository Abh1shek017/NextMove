# app/schemas.py
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class UserCreate(BaseModel):
    phone_number: str
    name: Optional[str] = None
    age_group: Optional[str] = None
    gender: Optional[str] = None
    occupation: Optional[str] = None
    income_group: Optional[str] = None

class Token(BaseModel):
    access_token: str
    token_type: str

# --- NEW: Trip schemas ---
class TripStartResponse(BaseModel):
    trip_id: int
    start_time: datetime

class TripStopRequest(BaseModel):
    purpose: Optional[str] = None

class TripResponse(BaseModel):
    id: int
    user_id: int
    start_time: datetime
    end_time: Optional[datetime]
    distance_km: Optional[float]
    duration_min: Optional[float]
    predicted_mode: Optional[str]
    confirmed_mode: Optional[str]
    purpose: Optional[str]