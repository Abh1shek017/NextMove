# app/services/ml_service.py
import os
import logging
import joblib

MODEL_PATH = "app/ml_models/mode_model.pkl"
model = None
FEATURES = ["avg_speed", "max_speed", "std_speed", "avg_acceleration", "stop_frequency", "distance_km"]

try:
    if os.path.exists(MODEL_PATH):
        model = joblib.load(MODEL_PATH)
        logging.info("✅ ML model loaded successfully")
    else:
        logging.warning("⚠️ ML model not found at %s", MODEL_PATH)
except Exception as e:
    logging.error("❌ Failed to load ML model: %s", str(e))

def predict_mode(features: dict) -> str:
    if model is None:
        # Fallback
        avg_speed = features.get("avg_speed", 0)
        if avg_speed < 5:
            return "walk"
        elif avg_speed < 15:
            return "bike"
        elif avg_speed < 40:
            return "bus"
        else:
            return "car"

    try:
        # Load label encoder
        label_encoder = joblib.load("app/ml_models/label_encoder.pkl")
        
        X = [[features.get(f, 0.0) for f in FEATURES]]
        prediction_encoded = model.predict(X)[0]
        prediction = label_encoder.inverse_transform([prediction_encoded])[0]
        return str(prediction)
    except Exception as e:
        logging.error("ML prediction error: %s", str(e))
        return "unknown"