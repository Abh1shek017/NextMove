from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.db import get_db
from app.models.trip import Trip
from app.schemas import TripStartResponse, TripStopRequest
from datetime import datetime, timezone
from app.services.feature_extraction import extract_features
from app.services.ml_service import predict_mode
from pydantic import BaseModel
import logging

# ---------------------------
# Logging Setup
# ---------------------------
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.DEBUG)

router = APIRouter(prefix="/trip", tags=["trips"])


# ---------------------------
# Trip Start
# ---------------------------
@router.post("/start", response_model=TripStartResponse)
async def start_trip(db: AsyncSession = Depends(get_db)):
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


# ---------------------------
# Trip Stop
# ---------------------------
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


# ---------------------------
# Predict Mode
# ---------------------------
@router.post("/predict_mode/{trip_id}")
async def predict_trip_mode(trip_id: int, db: AsyncSession = Depends(get_db)):
    try:
        logger.info(f"🔍 Starting prediction for trip_id={trip_id}")

        # Check trip exists
        result = await db.execute(select(Trip).where(Trip.id == trip_id))
        trip = result.scalars().first()
        if not trip:
            logger.warning(f"Trip {trip_id} not found")
            raise HTTPException(status_code=404, detail="Trip not found")

        # Extract features
        logger.info(f"📊 Extracting features for trip {trip_id}")
        features = await extract_features(db, trip_id)
        logger.info(f"Features extracted: {features}")

        if not features or not any(features.values()):
            logger.error(f"No valid features for trip {trip_id}")
            raise HTTPException(status_code=400, detail="Not enough GPS data to predict")

        # Predict
        logger.info(f"🧠 Running ML prediction with features: {features}")
        predicted_mode = predict_mode(features)
        logger.info(f"✅ Prediction result: {predicted_mode}")

        # Save prediction
        trip.predicted_mode = predicted_mode
        await db.commit()
        logger.info(f"💾 Saved prediction for trip {trip_id}")

        return {
            "trip_id": trip_id,
            "predicted_mode": predicted_mode,
            "features": features
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"💥 CRITICAL ERROR in predict_trip_mode for trip {trip_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


# ---------------------------
# Confirm Mode
# ---------------------------
class TripConfirmation(BaseModel):
    confirmed_mode: str  # e.g., "car", "bike", "bus", "walk"


@router.post("/confirm/{trip_id}")
async def confirm_trip_mode(
    trip_id: int,
    confirmation: TripConfirmation,
    db: AsyncSession = Depends(get_db)
):
    try:
        logger.info(f"✅ Starting confirmation for trip_id={trip_id}, mode={confirmation.confirmed_mode}")

        # Check trip exists
        result = await db.execute(select(Trip).where(Trip.id == trip_id))
        trip = result.scalars().first()
        if not trip:
            raise HTTPException(status_code=404, detail="Trip not found")

        # Save confirmed mode
        trip.confirmed_mode = confirmation.confirmed_mode
        await db.commit()
        logger.info("Trip confirmed in trips table")

        # Save to ML training data
        logger.info("Extracting features for training data")
        features = await extract_features(db, trip_id)
        if features:
            from app.models.ml_training import MLTrainingData
            training_data = MLTrainingData(
                trip_id=trip_id,
                avg_speed=float(features.get("avg_speed", 0)),
                max_speed=float(features.get("max_speed", 0)),
                std_speed=float(features.get("std_speed", 0)),
                avg_acceleration=float(features.get("avg_acceleration", 0)),
                stop_frequency=int(features.get("stop_frequency", 0)),
                distance_km=float(features.get("distance_km", 0)),
                mode_label=confirmation.confirmed_mode
            )
            db.add(training_data)
            await db.commit()
            logger.info("✅ Saved to ml_training_data")
        else:
            logger.warning("⚠️ No features for training data")

        return {
            "message": "Trip mode confirmed",
            "trip_id": trip_id,
            "confirmed_mode": confirmation.confirmed_mode
        }

    except Exception as e:
        logger.exception(f"💥 CRITICAL ERROR in confirm_trip_mode for trip {trip_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Confirmation failed: {str(e)}")
