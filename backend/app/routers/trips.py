from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func
from app.db import get_db
from app.models.trip import Trip
from app.models.user import User
from app.schemas import TripStartResponse, TripStopRequest
from datetime import datetime, timezone
from app.services.feature_extraction import extract_features
from app.services.ml_service import predict_mode
from pydantic import BaseModel
from app.utils.auth import get_current_user
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
async def start_trip(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    new_trip = Trip(user_id=current_user.id)
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
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Verify trip belongs to user
    result = await db.execute(
        select(Trip).where(Trip.id == trip_id, Trip.user_id == current_user.id)
    )
    trip = result.scalars().first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found or not owned by user")

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
async def predict_trip_mode(
    trip_id: int, 
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    try:
        logger.info(f"🔍 Starting prediction for trip_id={trip_id}")

        # Verify trip belongs to user
        result = await db.execute(
            select(Trip).where(Trip.id == trip_id, Trip.user_id == current_user.id)
        )
        trip = result.scalars().first()
        if not trip:
            logger.warning(f"Trip {trip_id} not found or not owned by user {current_user.id}")
            raise HTTPException(status_code=404, detail="Trip not found or not owned by user")

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
# Get Past Trips
# ---------------------------
@router.get("/past_trips")
async def get_past_trips(
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    try:
        # Get trips for the authenticated user
        result = await db.execute(
            select(Trip)
            .where(Trip.user_id == current_user.id)
            .where(Trip.end_time.isnot(None))  # Only completed trips
            .order_by(Trip.end_time.desc())
            .limit(limit)
            .offset(offset)
        )
        trips = result.scalars().all()

        # Get total count
        count_result = await db.execute(
            select(func.count(Trip.id))
            .where(Trip.user_id == current_user.id)
            .where(Trip.end_time.isnot(None))
        )
        total = count_result.scalar()

        return {
            "trips": [
                {
                    "trip_id": trip.id,
                    "start_time": trip.start_time,
                    "end_time": trip.end_time,
                    "duration_min": trip.duration_min,
                    "purpose": trip.purpose,
                    "predicted_mode": trip.predicted_mode,
                    "confirmed_mode": trip.confirmed_mode,
                    "distance_km": trip.distance_km,
                    "start_location": trip.start_location,
                    "end_location": trip.end_location,
                    "cost": trip.cost,
                    "companions": trip.companions,
                    "comment": trip.comment,
                }
                for trip in trips
            ],
            "total": total
        }

    except Exception as e:
        logger.exception(f"Error fetching past trips: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch trips: {str(e)}")


# ---------------------------
# Edit Trip
# ---------------------------
class TripEditRequest(BaseModel):
    purpose: str = None
    confirmed_mode: str = None
    start_location: str = None
    end_location: str = None
    cost: float = None
    companions: int = None
    comment: str = None

@router.put("/edit/{trip_id}")
async def edit_trip(
    trip_id: int,
    trip_data: TripEditRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    try:
        logger.info(f"📝 Starting edit for trip_id={trip_id}")
        
        # Verify trip belongs to user
        result = await db.execute(
            select(Trip).where(Trip.id == trip_id, Trip.user_id == current_user.id)
        )
        trip = result.scalars().first()
        if not trip:
            raise HTTPException(status_code=404, detail="Trip not found or not owned by user")
        
        # Check if trip is within 24 hours
        if trip.end_time:
            time_diff = datetime.now(timezone.utc) - trip.end_time
            if time_diff.total_seconds() > 24 * 3600:  # 24 hours in seconds
                raise HTTPException(
                    status_code=400, 
                    detail="Trip can only be edited within 24 hours of completion"
                )
        
        # Update trip fields if provided
        if trip_data.purpose is not None:
            trip.purpose = trip_data.purpose
        if trip_data.confirmed_mode is not None:
            trip.confirmed_mode = trip_data.confirmed_mode
        if trip_data.start_location is not None:
            trip.start_location = trip_data.start_location
        if trip_data.end_location is not None:
            trip.end_location = trip_data.end_location
        if trip_data.cost is not None:
            trip.cost = trip_data.cost
        if trip_data.companions is not None:
            trip.companions = trip_data.companions
        if trip_data.comment is not None:
            trip.comment = trip_data.comment
        
        await db.commit()
        logger.info(f"✅ Trip {trip_id} updated successfully")
        
        return {
            "message": "Trip updated successfully",
            "trip_id": trip_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"💥 Error editing trip {trip_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to edit trip: {str(e)}")


# ---------------------------
# Confirm Mode
# ---------------------------
class TripConfirmation(BaseModel):
    confirmed_mode: str  # e.g., "car", "bike", "bus", "walk"


@router.post("/confirm/{trip_id}")
async def confirm_trip_mode(
    trip_id: int,
    confirmation: TripConfirmation,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    try:
        logger.info(f"✅ Starting confirmation for trip_id={trip_id}, mode={confirmation.confirmed_mode}")

        # Verify trip belongs to user
        result = await db.execute(
            select(Trip).where(Trip.id == trip_id, Trip.user_id == current_user.id)
        )
        trip = result.scalars().first()
        if not trip:
            raise HTTPException(status_code=404, detail="Trip not found or not owned by user")

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
