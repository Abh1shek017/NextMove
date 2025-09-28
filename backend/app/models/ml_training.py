# app/models/ml_training.py
from sqlalchemy import Column, Integer, ForeignKey, Float, String
from app.database.base import Base

class MLTrainingData(Base):
    __tablename__ = "ml_training_data"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(Integer, ForeignKey("trips.id", ondelete="CASCADE"), nullable=False)
    avg_speed = Column(Float, nullable=False)
    max_speed = Column(Float, nullable=False)
    std_speed = Column(Float, nullable=False)
    avg_acceleration = Column(Float, nullable=False)
    stop_frequency = Column(Integer, nullable=False)
    distance_km = Column(Float, nullable=False)
    mode_label = Column(String(20), nullable=False)  # e.g., "car", "bike"