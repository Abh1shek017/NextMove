from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class TripStartResponse(BaseModel):
    trip_id: int
    start_time: datetime

class TripStopRequest(BaseModel):
    purpose: Optional[str] = None

class GPSLogCreate(BaseModel):
    latitude: float
    longitude: float
    speed: Optional[float] = None
    acceleration: Optional[float] = None

class GPSLogBatchCreate(BaseModel):
    trip_id: int
    logs: List[GPSLogCreate]