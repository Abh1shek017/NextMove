# app/models/user.py
from sqlalchemy import Column, Integer, String, DateTime, func
from app.database.base import Base  # ← shared Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(15), unique=True, index=True, nullable=False)
    name = Column(String(100))
    age_group = Column(String(20))
    gender = Column(String(10))
    occupation = Column(String(50))
    income_group = Column(String(20))
    created_at = Column(DateTime(timezone=True), server_default=func.now())