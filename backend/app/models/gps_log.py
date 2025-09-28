from sqlalchemy import Column, Integer, ForeignKey, DateTime, Float
from sqlalchemy.sql import func
from geoalchemy2 import Geography
from app.database.base import Base

class GPSLog(Base):
    __tablename__ = "gps_logs"
    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id", ondelete="CASCADE"), nullable=False)
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    location = Column(Geography("POINT", srid=4326), nullable=False)
    speed = Column(Float, nullable=True)
    acceleration = Column(Float, nullable=True)