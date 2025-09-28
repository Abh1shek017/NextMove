from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from geoalchemy2.elements import WKTElement
from app.db import get_db
from app.models.gps_log import GPSLog
from app.models.trip import Trip
from app.schemas import GPSLogBatchCreate

router = APIRouter(prefix="/gps", tags=["gps"])

@router.post("/batch")
async def log_gps_batch(batch: GPSLogBatchCreate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Trip).where(Trip.id == batch.trip_id))
    trip = result.scalars().first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    gps_logs = []
    for log in batch.logs:
        point = WKTElement(f"POINT({log.longitude} {log.latitude})", srid=4326)
        gps_logs.append(GPSLog(
            trip_id=batch.trip_id,
            location=point,
            speed=log.speed,
            acceleration=log.acceleration
        ))
    
    db.add_all(gps_logs)
    await db.commit()
    return {"logged_count": len(gps_logs)}