# app/services/trip_detection_ml.py
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import joblib
import logging
from typing import Dict, List, Tuple
import os

logger = logging.getLogger(__name__)

class TripDetectionML:
    def __init__(self):
        self.start_model = None
        self.end_model = None
        self.scaler = StandardScaler()
        self.is_trained = False
        
        # Model paths
        self.start_model_path = "app/ml_models/trip_start_model.pkl"
        self.end_model_path = "app/ml_models/trip_end_model.pkl"
        self.scaler_path = "app/ml_models/trip_detection_scaler.pkl"
        
        # Load existing models if available
        self._load_models()
    
    def _load_models(self):
        """Load pre-trained models if they exist"""
        try:
            if os.path.exists(self.start_model_path):
                self.start_model = joblib.load(self.start_model_path)
                logger.info("✅ Trip start model loaded")
            
            if os.path.exists(self.end_model_path):
                self.end_model = joblib.load(self.end_model_path)
                logger.info("✅ Trip end model loaded")
                
            if os.path.exists(self.scaler_path):
                self.scaler = joblib.load(self.scaler_path)
                logger.info("✅ Trip detection scaler loaded")
                
            if self.start_model and self.end_model:
                self.is_trained = True
                logger.info("✅ Trip detection ML models ready")
                
        except Exception as e:
            logger.error(f"❌ Failed to load trip detection models: {e}")
    
    def extract_motion_features(self, sensor_data: List[Dict]) -> Dict:
        """
        Extract features from sensor data for trip start/end detection
        
        Args:
            sensor_data: List of sensor readings with keys:
                - acceleration_x, acceleration_y, acceleration_z
                - gyroscope_x, gyroscope_y, gyroscope_z
                - timestamp
                - speed (optional)
                - location (optional)
        
        Returns:
            Feature dictionary for ML model
        """
        if not sensor_data or len(sensor_data) < 10:
            return {}
        
        # Convert to numpy arrays for easier processing
        accel_x = np.array([d.get('acceleration_x', 0) for d in sensor_data])
        accel_y = np.array([d.get('acceleration_y', 0) for d in sensor_data])
        accel_z = np.array([d.get('acceleration_z', 0) for d in sensor_data])
        
        gyro_x = np.array([d.get('gyroscope_x', 0) for d in sensor_data])
        gyro_y = np.array([d.get('gyroscope_y', 0) for d in sensor_data])
        gyro_z = np.array([d.get('gyroscope_z', 0) for d in sensor_data])
        
        speeds = np.array([d.get('speed', 0) for d in sensor_data if d.get('speed') is not None])
        
        # Calculate magnitude vectors
        accel_magnitude = np.sqrt(accel_x**2 + accel_y**2 + accel_z**2)
        gyro_magnitude = np.sqrt(gyro_x**2 + gyro_y**2 + gyro_z**2)
        
        # Remove gravity (approximately 9.81 m/s²)
        net_acceleration = np.abs(accel_magnitude - 9.81)
        
        # Statistical features
        features = {
            # Acceleration features
            'accel_mean': float(np.mean(net_acceleration)),
            'accel_std': float(np.std(net_acceleration)),
            'accel_max': float(np.max(net_acceleration)),
            'accel_min': float(np.min(net_acceleration)),
            'accel_median': float(np.median(net_acceleration)),
            'accel_q75': float(np.percentile(net_acceleration, 75)),
            'accel_q25': float(np.percentile(net_acceleration, 25)),
            
            # Gyroscope features
            'gyro_mean': float(np.mean(gyro_magnitude)),
            'gyro_std': float(np.std(gyro_magnitude)),
            'gyro_max': float(np.max(gyro_magnitude)),
            
            # Motion pattern features
            'accel_variance': float(np.var(net_acceleration)),
            'accel_skewness': float(self._skewness(net_acceleration)),
            'accel_kurtosis': float(self._kurtosis(net_acceleration)),
            
            # Speed features (if available)
            'speed_mean': float(np.mean(speeds)) if len(speeds) > 0 else 0.0,
            'speed_std': float(np.std(speeds)) if len(speeds) > 0 else 0.0,
            'speed_max': float(np.max(speeds)) if len(speeds) > 0 else 0.0,
            
            # Temporal features
            'data_points': len(sensor_data),
            'time_span': float((sensor_data[-1]['timestamp'] - sensor_data[0]['timestamp']).total_seconds()) if len(sensor_data) > 1 else 0.0,
            
            # Motion intensity features
            'high_motion_ratio': float(np.sum(net_acceleration > 2.0) / len(net_acceleration)),
            'low_motion_ratio': float(np.sum(net_acceleration < 0.5) / len(net_acceleration)),
            'motion_consistency': float(1.0 - np.std(net_acceleration) / (np.mean(net_acceleration) + 1e-6)),
        }
        
        return features
    
    def _skewness(self, data):
        """Calculate skewness"""
        if len(data) < 3:
            return 0.0
        mean = np.mean(data)
        std = np.std(data)
        if std == 0:
            return 0.0
        return np.mean(((data - mean) / std) ** 3)
    
    def _kurtosis(self, data):
        """Calculate kurtosis"""
        if len(data) < 4:
            return 0.0
        mean = np.mean(data)
        std = np.std(data)
        if std == 0:
            return 0.0
        return np.mean(((data - mean) / std) ** 4) - 3
    
    def predict_trip_start(self, features: Dict) -> Tuple[bool, float]:
        """
        Predict if a trip is starting based on sensor features
        
        Returns:
            (is_trip_starting, confidence_score)
        """
        if not self.is_trained or not self.start_model:
            # Fallback to rule-based detection
            return self._fallback_trip_start_detection(features)
        
        try:
            # Prepare features for model
            feature_vector = self._prepare_feature_vector(features)
            
            # Scale features
            feature_vector_scaled = self.scaler.transform([feature_vector])
            
            # Predict
            prediction = self.start_model.predict(feature_vector_scaled)[0]
            confidence = self.start_model.predict_proba(feature_vector_scaled)[0].max()
            
            return bool(prediction), float(confidence)
            
        except Exception as e:
            logger.error(f"ML trip start prediction error: {e}")
            return self._fallback_trip_start_detection(features)
    
    def predict_trip_end(self, features: Dict) -> Tuple[bool, float]:
        """
        Predict if a trip is ending based on sensor features
        
        Returns:
            (is_trip_ending, confidence_score)
        """
        if not self.is_trained or not self.end_model:
            # Fallback to rule-based detection
            return self._fallback_trip_end_detection(features)
        
        try:
            # Prepare features for model
            feature_vector = self._prepare_feature_vector(features)
            
            # Scale features
            feature_vector_scaled = self.scaler.transform([feature_vector])
            
            # Predict
            prediction = self.end_model.predict(feature_vector_scaled)[0]
            confidence = self.end_model.predict_proba(feature_vector_scaled)[0].max()
            
            return bool(prediction), float(confidence)
            
        except Exception as e:
            logger.error(f"ML trip end prediction error: {e}")
            return self._fallback_trip_end_detection(features)
    
    def _prepare_feature_vector(self, features: Dict) -> List[float]:
        """Prepare feature vector in the correct order for ML models"""
        feature_order = [
            'accel_mean', 'accel_std', 'accel_max', 'accel_min', 'accel_median',
            'accel_q75', 'accel_q25', 'gyro_mean', 'gyro_std', 'gyro_max',
            'accel_variance', 'accel_skewness', 'accel_kurtosis',
            'speed_mean', 'speed_std', 'speed_max',
            'data_points', 'time_span',
            'high_motion_ratio', 'low_motion_ratio', 'motion_consistency'
        ]
        
        return [features.get(key, 0.0) for key in feature_order]
    
    def _fallback_trip_start_detection(self, features: Dict) -> Tuple[bool, float]:
        """Rule-based fallback for trip start detection"""
        accel_mean = features.get('accel_mean', 0)
        accel_std = features.get('accel_std', 0)
        speed_mean = features.get('speed_mean', 0)
        high_motion_ratio = features.get('high_motion_ratio', 0)
        
        # Simple rule-based detection
        is_starting = (
            accel_mean > 1.0 and  # Significant motion
            accel_std > 0.5 and   # Variable motion
            speed_mean > 1.0 and  # Moving at reasonable speed
            high_motion_ratio > 0.3  # Consistent motion
        )
        
        confidence = 0.6 if is_starting else 0.4
        return is_starting, confidence
    
    def _fallback_trip_end_detection(self, features: Dict) -> Tuple[bool, float]:
        """Rule-based fallback for trip end detection"""
        accel_mean = features.get('accel_mean', 0)
        speed_mean = features.get('speed_mean', 0)
        low_motion_ratio = features.get('low_motion_ratio', 0)
        
        # Simple rule-based detection
        is_ending = (
            accel_mean < 0.8 and  # Low motion
            speed_mean < 2.0 and  # Low speed
            low_motion_ratio > 0.7  # Mostly stationary
        )
        
        confidence = 0.7 if is_ending else 0.3
        return is_ending, confidence
    
    def train_models(self, training_data: List[Dict]):
        """
        Train the ML models for trip start/end detection
        
        Args:
            training_data: List of training examples with features and labels
                Each example should have:
                - features: sensor feature dictionary
                - trip_start_label: bool (True if trip started)
                - trip_end_label: bool (True if trip ended)
        """
        if not training_data or len(training_data) < 100:
            logger.warning("⚠️ Insufficient training data for trip detection ML")
            return False
        
        try:
            # Prepare training data
            X = []
            y_start = []
            y_end = []
            
            for example in training_data:
                features = example['features']
                feature_vector = self._prepare_feature_vector(features)
                X.append(feature_vector)
                y_start.append(example['trip_start_label'])
                y_end.append(example['trip_end_label'])
            
            X = np.array(X)
            y_start = np.array(y_start)
            y_end = np.array(y_end)
            
            # Scale features
            X_scaled = self.scaler.fit_transform(X)
            
            # Split data
            X_train, X_test, y_start_train, y_start_test = train_test_split(
                X_scaled, y_start, test_size=0.2, random_state=42
            )
            _, _, y_end_train, y_end_test = train_test_split(
                X_scaled, y_end, test_size=0.2, random_state=42
            )
            
            # Train trip start model
            self.start_model = RandomForestClassifier(
                n_estimators=100,
                max_depth=10,
                random_state=42,
                class_weight='balanced'
            )
            self.start_model.fit(X_train, y_start_train)
            
            # Train trip end model
            self.end_model = RandomForestClassifier(
                n_estimators=100,
                max_depth=10,
                random_state=42,
                class_weight='balanced'
            )
            self.end_model.fit(X_train, y_end_train)
            
            # Evaluate models
            start_accuracy = self.start_model.score(X_test, y_start_test)
            end_accuracy = self.end_model.score(X_test, y_end_test)
            
            logger.info(f"✅ Trip start model accuracy: {start_accuracy:.3f}")
            logger.info(f"✅ Trip end model accuracy: {end_accuracy:.3f}")
            
            # Save models
            os.makedirs("app/ml_models", exist_ok=True)
            joblib.dump(self.start_model, self.start_model_path)
            joblib.dump(self.end_model, self.end_model_path)
            joblib.dump(self.scaler, self.scaler_path)
            
            self.is_trained = True
            logger.info("✅ Trip detection ML models trained and saved")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Failed to train trip detection models: {e}")
            return False

# Global instance
trip_detection_ml = TripDetectionML()
