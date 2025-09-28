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