# app/routers/ml.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Dict, Any, List
import logging

from app.db import get_db
from app.models.user import User
from app.utils.auth import get_current_user
from app.services.trip_detection_ml import trip_detection_ml
from app.models.trip_detection_training import TripDetectionTraining

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ml", tags=["machine-learning"])

# ---------------------------
# Request/Response Models
# ---------------------------

class TripDetectionPredictionRequest(BaseModel):
    features: Dict[str, Any]

class TripDetectionPredictionResponse(BaseModel):
    trip_start: bool
    trip_end: bool
    start_confidence: float
    end_confidence: float

class TrainingDataSubmission(BaseModel):
    features: Dict[str, Any]
    trip_start_label: bool
    trip_end_label: bool
    context: str = None

class MLModelStatus(BaseModel):
    is_trained: bool
    start_model_available: bool
    end_model_available: bool
    scaler_available: bool

# ---------------------------
# ML Prediction Endpoints
# ---------------------------

@router.post("/predict_trip_detection", response_model=TripDetectionPredictionResponse)
async def predict_trip_detection(
    request: TripDetectionPredictionRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Predict trip start/end based on sensor features using ML models
    """
    try:
        logger.info(f"🧠 ML prediction request from user {current_user.id}")
        
        # Extract features
        features = request.features
        
        # Make predictions
        is_trip_starting, start_confidence = trip_detection_ml.predict_trip_start(features)
        is_trip_ending, end_confidence = trip_detection_ml.predict_trip_end(features)
        
        logger.info(f"ML Prediction - Start: {is_trip_starting} ({start_confidence:.3f}), End: {is_trip_ending} ({end_confidence:.3f})")
        
        return TripDetectionPredictionResponse(
            trip_start=is_trip_starting,
            trip_end=is_trip_ending,
            start_confidence=start_confidence,
            end_confidence=end_confidence
        )
        
    except Exception as e:
        logger.error(f"❌ ML prediction error: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")

# ---------------------------
# Training Data Submission
# ---------------------------

@router.post("/submit_training_data")
async def submit_training_data(
    training_data: TrainingDataSubmission,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Submit training data for ML model improvement
    """
    try:
        logger.info(f"📚 Training data submission from user {current_user.id}")
        
        features = training_data.features
        
        # Create training data record
        training_record = TripDetectionTraining(
            # Sensor features
            accel_mean=float(features.get('accel_mean', 0)),
            accel_std=float(features.get('accel_std', 0)),
            accel_max=float(features.get('accel_max', 0)),
            accel_min=float(features.get('accel_min', 0)),
            accel_median=float(features.get('accel_median', 0)),
            accel_q75=float(features.get('accel_q75', 0)),
            accel_q25=float(features.get('accel_q25', 0)),
            
            gyro_mean=float(features.get('gyro_mean', 0)),
            gyro_std=float(features.get('gyro_std', 0)),
            gyro_max=float(features.get('gyro_max', 0)),
            
            accel_variance=float(features.get('accel_variance', 0)),
            accel_skewness=float(features.get('accel_skewness', 0)),
            accel_kurtosis=float(features.get('accel_kurtosis', 0)),
            
            speed_mean=float(features.get('speed_mean', 0)),
            speed_std=float(features.get('speed_std', 0)),
            speed_max=float(features.get('speed_max', 0)),
            
            data_points=int(features.get('data_points', 0)),
            time_span=float(features.get('time_span', 0)),
            
            high_motion_ratio=float(features.get('high_motion_ratio', 0)),
            low_motion_ratio=float(features.get('low_motion_ratio', 0)),
            motion_consistency=float(features.get('motion_consistency', 0)),
            
            # Labels
            trip_start_label=training_data.trip_start_label,
            trip_end_label=training_data.trip_end_label,
            
            # Metadata
            user_id=current_user.id,
            context=training_data.context,
        )
        
        db.add(training_record)
        await db.commit()
        
        logger.info(f"✅ Training data saved for user {current_user.id}")
        
        return {
            "message": "Training data submitted successfully",
            "training_id": training_record.id
        }
        
    except Exception as e:
        logger.error(f"❌ Training data submission error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to submit training data: {str(e)}")

# ---------------------------
# Model Status and Management
# ---------------------------

@router.get("/status", response_model=MLModelStatus)
async def get_ml_model_status():
    """
    Get status of ML models for trip detection
    """
    try:
        return MLModelStatus(
            is_trained=trip_detection_ml.is_trained,
            start_model_available=trip_detection_ml.start_model is not None,
            end_model_available=trip_detection_ml.end_model is not None,
            scaler_available=trip_detection_ml.scaler is not None
        )
    except Exception as e:
        logger.error(f"❌ ML status check error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to get ML status: {str(e)}")

@router.post("/retrain_models")
async def retrain_models(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Retrain ML models with collected training data
    """
    try:
        logger.info(f"🔄 Retraining ML models triggered by user {current_user.id}")
        
        # Get training data from database
        from sqlalchemy import select
        result = await db.execute(select(TripDetectionTraining))
        training_records = result.scalars().all()
        
        if len(training_records) < 100:
            raise HTTPException(
                status_code=400, 
                detail=f"Insufficient training data: {len(training_records)} records. Need at least 100."
            )
        
        # Convert to training format
        training_data = []
        for record in training_records:
            features = {
                'accel_mean': record.accel_mean,
                'accel_std': record.accel_std,
                'accel_max': record.accel_max,
                'accel_min': record.accel_min,
                'accel_median': record.accel_median,
                'accel_q75': record.accel_q75,
                'accel_q25': record.accel_q25,
                'gyro_mean': record.gyro_mean,
                'gyro_std': record.gyro_std,
                'gyro_max': record.gyro_max,
                'accel_variance': record.accel_variance,
                'accel_skewness': record.accel_skewness,
                'accel_kurtosis': record.accel_kurtosis,
                'speed_mean': record.speed_mean,
                'speed_std': record.speed_std,
                'speed_max': record.speed_max,
                'data_points': record.data_points,
                'time_span': record.time_span,
                'high_motion_ratio': record.high_motion_ratio,
                'low_motion_ratio': record.low_motion_ratio,
                'motion_consistency': record.motion_consistency,
            }
            
            training_data.append({
                'features': features,
                'trip_start_label': record.trip_start_label,
                'trip_end_label': record.trip_end_label,
            })
        
        # Train models
        success = trip_detection_ml.train_models(training_data)
        
        if success:
            return {
                "message": "Models retrained successfully",
                "training_samples": len(training_data),
                "models_updated": True
            }
        else:
            raise HTTPException(status_code=500, detail="Model training failed")
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Model retraining error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to retrain models: {str(e)}")

# ---------------------------
# Feature Analysis
# ---------------------------

@router.post("/analyze_features")
async def analyze_features(
    request: TripDetectionPredictionRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Analyze sensor features and provide insights
    """
    try:
        features = request.features
        
        # Basic analysis
        analysis = {
            "motion_intensity": "low" if features.get('accel_mean', 0) < 1.0 else "high" if features.get('accel_mean', 0) > 2.5 else "medium",
            "motion_consistency": "consistent" if features.get('motion_consistency', 0) > 0.7 else "variable",
            "speed_category": "stationary" if features.get('speed_mean', 0) < 1 else "slow" if features.get('speed_mean', 0) < 10 else "fast",
            "data_quality": "good" if features.get('data_points', 0) > 20 else "limited",
            "trip_start_probability": "high" if features.get('accel_mean', 0) > 1.5 and features.get('speed_mean', 0) > 2 else "low",
            "trip_end_probability": "high" if features.get('accel_mean', 0) < 0.8 and features.get('speed_mean', 0) < 2 else "low",
        }
        
        return {
            "analysis": analysis,
            "raw_features": features,
            "recommendation": "Use ML prediction for better accuracy" if trip_detection_ml.is_trained else "Use rule-based detection"
        }
        
    except Exception as e:
        logger.error(f"❌ Feature analysis error: {e}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")
