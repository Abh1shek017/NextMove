from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db import get_db
from app.models.trip import Trip
from app.schemas import TripStartResponse, TripStopRequest
from datetime import datetime, timezone
from app.services.feature_extraction import extract_features
from app.services.ml_service import predict_mode

router = APIRouter(prefix="/trip", tags=["trips"])

@router.post("/start", response_model=TripStartResponse)
async def start_trip(db: AsyncSession = Depends(get_db)):
    # Create a dummy user if none exists (for testing)
    from app.models.user import User
    result = await db.execute(select(User).limit(1))
    user = result.scalars().first()
    if not user:
        user = User(phone_number="+910000000000")
        db.add(user)
        await db.commit()
        await db.refresh(user)

    new_trip = Trip(user_id=user.id)
    db.add(new_trip)
    await db.commit()
    await db.refresh(new_trip)
    return TripStartResponse(trip_id=new_trip.id, start_time=new_trip.start_time)

@router.post("/stop/{trip_id}")
async def stop_trip(
    trip_id: int,
    trip_data: TripStopRequest,
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(Trip).where(Trip.id == trip_id))
    trip = result.scalars().first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")

    if trip.end_time:
        raise HTTPException(status_code=400, detail="Trip already stopped")

    trip.end_time = datetime.now(timezone.utc)
    trip.purpose = trip_data.purpose

    if trip.start_time:
        duration = (trip.end_time - trip.start_time).total_seconds() / 60
        trip.duration_min = round(duration, 2)

    await db.commit()
    return {"message": "Trip stopped", "trip_id": trip_id}
import logging
logging.basicConfig(level=logging.DEBUG)

@router.post("/predict_mode/{trip_id}")
async def predict_trip_mode(trip_id: int, db: AsyncSession = Depends(get_db)):
    try:
        result = await db.execute(select(Trip).where(Trip.id == trip_id))
        trip = result.scalars().first()
        if not trip:
            raise HTTPException(status_code=404, detail="Trip not found")

        features = await extract_features(db, trip_id)
        if not features:
            raise HTTPException(status_code=400, detail="Not enough GPS data")

        logging.info(f"Features for trip {trip_id}: {features}")

        predicted_mode = predict_mode(features)

        trip.predicted_mode = predicted_mode
        await db.commit()

        return {
            "trip_id": trip_id,
            "predicted_mode": predicted_mode,
            "features": features
        }
    except Exception as e:
        logging.error(f"Prediction error for trip {trip_id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Prediction failed")