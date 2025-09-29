from sqlalchemy import Column, Integer, String, DateTime, func
from app.database.base import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(15), unique=True, index=True, nullable=False)
    
    # Profile information
    name = Column(String(100), nullable=True)
    age_group = Column(String(20), nullable=True)
    gender = Column(String(10), nullable=True)
    occupation = Column(String(50), nullable=True)
    income_group = Column(String(30), nullable=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())