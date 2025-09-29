from sqlalchemy import Column, Integer, ForeignKey, DateTime, Float, String
from sqlalchemy.sql import func
from app.database.base import Base

class Trip(Base):
    __tablename__ = "trips"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    start_time = Column(DateTime(timezone=True), server_default=func.now())
    end_time = Column(DateTime(timezone=True), nullable=True)
    duration_min = Column(Float, nullable=True)
    purpose = Column(String(50), nullable=True)
    predicted_mode = Column(String(20), nullable=True)
    confirmed_mode = Column(String(20), nullable=True)
    distance_km = Column(Float, nullable=True)
    start_location = Column(String(100), nullable=True)
    end_location = Column(String(100), nullable=True)
    cost = Column(Float, nullable=True)
    companions = Column(Integer, nullable=True, default=0)
    comment = Column(String(500), nullable=True)