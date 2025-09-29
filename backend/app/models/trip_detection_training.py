# app/models/trip_detection_training.py
from sqlalchemy import Column, Integer, Float, Boolean, DateTime, Text, JSON
from sqlalchemy.sql import func
from app.database.base import Base

class TripDetectionTraining(Base):
    __tablename__ = "trip_detection_training"
    
    id = Column(Integer, primary_key=True, index=True)
    
    # Sensor features
    accel_mean = Column(Float, nullable=False)
    accel_std = Column(Float, nullable=False)
    accel_max = Column(Float, nullable=False)
    accel_min = Column(Float, nullable=False)
    accel_median = Column(Float, nullable=False)
    accel_q75 = Column(Float, nullable=False)
    accel_q25 = Column(Float, nullable=False)
    
    gyro_mean = Column(Float, nullable=False)
    gyro_std = Column(Float, nullable=False)
    gyro_max = Column(Float, nullable=False)
    
    accel_variance = Column(Float, nullable=False)
    accel_skewness = Column(Float, nullable=False)
    accel_kurtosis = Column(Float, nullable=False)
    
    speed_mean = Column(Float, nullable=False, default=0.0)
    speed_std = Column(Float, nullable=False, default=0.0)
    speed_max = Column(Float, nullable=False, default=0.0)
    
    data_points = Column(Integer, nullable=False)
    time_span = Column(Float, nullable=False)
    
    high_motion_ratio = Column(Float, nullable=False)
    low_motion_ratio = Column(Float, nullable=False)
    motion_consistency = Column(Float, nullable=False)
    
    # Labels
    trip_start_label = Column(Boolean, nullable=False)
    trip_end_label = Column(Boolean, nullable=False)
    
    # Metadata
    user_id = Column(Integer, nullable=True)  # Optional: for user-specific models
    context = Column(Text, nullable=True)  # Additional context (e.g., "walking", "biking")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Raw sensor data (for debugging/reanalysis)
    raw_sensor_data = Column(JSON, nullable=True)
