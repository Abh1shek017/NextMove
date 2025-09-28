# app/schemas.py
from pydantic import BaseModel
from typing import Optional

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