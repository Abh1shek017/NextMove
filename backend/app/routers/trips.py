# app/routers/trips.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db import get_db
from app.models.trip import Trip
from app.schemas import TripStartResponse, TripStopRequest, TripResponse
from app.utils.auth import get_current_user
from app.models.user import User
from datetime import datetime

router = APIRouter(prefix="/trip", tags=["trips"])

@router.post("/start", response_model=TripStartResponse)
async def start_trip(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    new_trip = Trip(user_id=current_user.id)
    db.add(new_trip)
    await db.commit()
    await db.refresh(new_trip)
    return TripStartResponse(trip_id=new_trip.id, start_time=new_trip.start_time)

@router.post("/stop/{trip_id}", response_model=TripResponse)
async def stop_trip(
    trip_id: int,
    trip_data: TripStopRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Fetch trip and verify ownership
    result = await db.execute(
        select(Trip).where(Trip.id == trip_id, Trip.user_id == current_user.id)
    )
    trip = result.scalars().first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found or not owned by user")
    
    if trip.end_time is not None:
        raise HTTPException(status_code=400, detail="Trip already stopped")

    # Set end time and purpose
    trip.end_time = datetime.utcnow()
    trip.purpose = trip_data.purpose

    # Calculate duration (in minutes)
    if trip.start_time:
        duration = (trip.end_time - trip.start_time).total_seconds() / 60
        trip.duration_min = round(duration, 2)

    await db.commit()
    await db.refresh(trip)
    return trip