from sqlalchemy import Column, Integer, String, DateTime, func
from app.database.base import Base

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(15), unique=True, index=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())