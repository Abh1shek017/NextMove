# backend/train_trip_detection.py
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
import joblib
import os

def generate_synthetic_trip_detection_data():
    """Generate synthetic training data for trip start/end detection"""
    np.random.seed(42)
    n_samples = 2000
    
    data = []
    
    for _ in range(n_samples):
        # Simulate different motion patterns
        motion_type = np.random.choice(["stationary", "walking", "biking", "driving", "transition"])
        
        if motion_type == "stationary":
            # Stationary - low motion, no trip start/end
            accel_mean = np.random.uniform(0.1, 0.5)
            accel_std = np.random.uniform(0.05, 0.2)
            accel_max = accel_mean + np.random.uniform(0.1, 0.5)
            accel_min = max(0, accel_mean - np.random.uniform(0.1, 0.3))
            accel_median = accel_mean + np.random.uniform(-0.1, 0.1)
            accel_q75 = accel_mean + np.random.uniform(0.1, 0.3)
            accel_q25 = max(0, accel_mean - np.random.uniform(0.1, 0.2))
            
            gyro_mean = np.random.uniform(0.01, 0.1)
            gyro_std = np.random.uniform(0.005, 0.05)
            gyro_max = gyro_mean + np.random.uniform(0.01, 0.1)
            
            speed_mean = np.random.uniform(0, 1)
            speed_std = np.random.uniform(0, 0.5)
            speed_max = speed_mean + np.random.uniform(0, 1)
            
            high_motion_ratio = np.random.uniform(0, 0.1)
            low_motion_ratio = np.random.uniform(0.8, 1.0)
            
            trip_start_label = False
            trip_end_label = False
            
        elif motion_type == "walking":
            # Walking - moderate motion, potential trip start
            accel_mean = np.random.uniform(1.0, 2.5)
            accel_std = np.random.uniform(0.3, 0.8)
            accel_max = accel_mean + np.random.uniform(0.5, 1.5)
            accel_min = max(0.1, accel_mean - np.random.uniform(0.3, 0.8))
            accel_median = accel_mean + np.random.uniform(-0.2, 0.2)
            accel_q75 = accel_mean + np.random.uniform(0.2, 0.6)
            accel_q25 = max(0.1, accel_mean - np.random.uniform(0.2, 0.5))
            
            gyro_mean = np.random.uniform(0.2, 0.8)
            gyro_std = np.random.uniform(0.1, 0.4)
            gyro_max = gyro_mean + np.random.uniform(0.2, 0.6)
            
            speed_mean = np.random.uniform(3, 6)
            speed_std = np.random.uniform(0.5, 1.5)
            speed_max = speed_mean + np.random.uniform(1, 3)
            
            high_motion_ratio = np.random.uniform(0.3, 0.7)
            low_motion_ratio = np.random.uniform(0.1, 0.4)
            
            trip_start_label = np.random.choice([True, False], p=[0.7, 0.3])  # 70% chance of trip start
            trip_end_label = False
            
        elif motion_type == "biking":
            # Biking - smoother motion than walking
            accel_mean = np.random.uniform(0.8, 2.0)
            accel_std = np.random.uniform(0.2, 0.6)
            accel_max = accel_mean + np.random.uniform(0.3, 1.0)
            accel_min = max(0.1, accel_mean - np.random.uniform(0.2, 0.6))
            accel_median = accel_mean + np.random.uniform(-0.15, 0.15)
            accel_q75 = accel_mean + np.random.uniform(0.15, 0.5)
            accel_q25 = max(0.1, accel_mean - np.random.uniform(0.15, 0.4))
            
            gyro_mean = np.random.uniform(0.1, 0.5)
            gyro_std = np.random.uniform(0.05, 0.3)
            gyro_max = gyro_mean + np.random.uniform(0.1, 0.4)
            
            speed_mean = np.random.uniform(15, 25)
            speed_std = np.random.uniform(2, 8)
            speed_max = speed_mean + np.random.uniform(5, 15)
            
            high_motion_ratio = np.random.uniform(0.2, 0.6)
            low_motion_ratio = np.random.uniform(0.1, 0.3)
            
            trip_start_label = np.random.choice([True, False], p=[0.8, 0.2])  # 80% chance of trip start
            trip_end_label = False
            
        elif motion_type == "driving":
            # Driving - variable motion, ongoing trip
            accel_mean = np.random.uniform(1.5, 3.5)
            accel_std = np.random.uniform(0.8, 2.0)
            accel_max = accel_mean + np.random.uniform(1.0, 3.0)
            accel_min = max(0.1, accel_mean - np.random.uniform(0.5, 1.5))
            accel_median = accel_mean + np.random.uniform(-0.3, 0.3)
            accel_q75 = accel_mean + np.random.uniform(0.5, 1.5)
            accel_q25 = max(0.1, accel_mean - np.random.uniform(0.3, 1.0))
            
            gyro_mean = np.random.uniform(0.3, 1.2)
            gyro_std = np.random.uniform(0.2, 0.8)
            gyro_max = gyro_mean + np.random.uniform(0.3, 1.0)
            
            speed_mean = np.random.uniform(25, 60)
            speed_std = np.random.uniform(5, 20)
            speed_max = speed_mean + np.random.uniform(10, 30)
            
            high_motion_ratio = np.random.uniform(0.4, 0.8)
            low_motion_ratio = np.random.uniform(0.05, 0.2)
            
            trip_start_label = False  # Already in trip
            trip_end_label = np.random.choice([True, False], p=[0.3, 0.7])  # 30% chance of trip end
            
        else:  # transition
            # Transition states - potential trip start or end
            accel_mean = np.random.uniform(0.5, 2.0)
            accel_std = np.random.uniform(0.4, 1.2)
            accel_max = accel_mean + np.random.uniform(0.5, 2.0)
            accel_min = max(0.05, accel_mean - np.random.uniform(0.3, 1.0))
            accel_median = accel_mean + np.random.uniform(-0.2, 0.2)
            accel_q75 = accel_mean + np.random.uniform(0.3, 1.0)
            accel_q25 = max(0.05, accel_mean - np.random.uniform(0.2, 0.8))
            
            gyro_mean = np.random.uniform(0.1, 0.8)
            gyro_std = np.random.uniform(0.1, 0.6)
            gyro_max = gyro_mean + np.random.uniform(0.2, 0.8)
            
            speed_mean = np.random.uniform(0, 15)
            speed_std = np.random.uniform(0, 5)
            speed_max = speed_mean + np.random.uniform(0, 10)
            
            high_motion_ratio = np.random.uniform(0.1, 0.6)
            low_motion_ratio = np.random.uniform(0.2, 0.8)
            
            trip_start_label = np.random.choice([True, False], p=[0.4, 0.6])
            trip_end_label = np.random.choice([True, False], p=[0.4, 0.6])
        
        # Additional features
        accel_variance = accel_std ** 2
        accel_skewness = np.random.uniform(-1, 1)  # Simplified
        accel_kurtosis = np.random.uniform(-1, 2)  # Simplified
        
        data_points = np.random.randint(10, 100)
        time_span = np.random.uniform(5, 60)  # seconds
        motion_consistency = 1.0 - (accel_std / (accel_mean + 1e-6))
        motion_consistency = max(0, min(1, motion_consistency))  # Clamp to [0,1]
        
        data.append({
            "accel_mean": accel_mean,
            "accel_std": accel_std,
            "accel_max": accel_max,
            "accel_min": accel_min,
            "accel_median": accel_median,
            "accel_q75": accel_q75,
            "accel_q25": accel_q25,
            "gyro_mean": gyro_mean,
            "gyro_std": gyro_std,
            "gyro_max": gyro_max,
            "accel_variance": accel_variance,
            "accel_skewness": accel_skewness,
            "accel_kurtosis": accel_kurtosis,
            "speed_mean": speed_mean,
            "speed_std": speed_std,
            "speed_max": speed_max,
            "data_points": data_points,
            "time_span": time_span,
            "high_motion_ratio": high_motion_ratio,
            "low_motion_ratio": low_motion_ratio,
            "motion_consistency": motion_consistency,
            "trip_start_label": trip_start_label,
            "trip_end_label": trip_end_label,
        })
    
    return pd.DataFrame(data)

def train_trip_detection_models():
    """Train ML models for trip start/end detection"""
    print("Generating synthetic training data...")
    df = generate_synthetic_trip_detection_data()
    
    print(f"Generated {len(df)} training samples")
    print(f"Trip starts: {df['trip_start_label'].sum()}")
    print(f"Trip ends: {df['trip_end_label'].sum()}")
    
    # Feature columns
    feature_cols = [
        'accel_mean', 'accel_std', 'accel_max', 'accel_min', 'accel_median',
        'accel_q75', 'accel_q25', 'gyro_mean', 'gyro_std', 'gyro_max',
        'accel_variance', 'accel_skewness', 'accel_kurtosis',
        'speed_mean', 'speed_std', 'speed_max',
        'data_points', 'time_span',
        'high_motion_ratio', 'low_motion_ratio', 'motion_consistency'
    ]
    
    X = df[feature_cols]
    
    # Train trip start model
    print("Training trip start detection model...")
    y_start = df['trip_start_label']
    X_train, X_test, y_start_train, y_start_test = train_test_split(
        X, y_start, test_size=0.2, random_state=42, stratify=y_start
    )
    
    start_model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        random_state=42,
        class_weight='balanced'
    )
    start_model.fit(X_train, y_start_train)
    
    start_accuracy = start_model.score(X_test, y_start_test)
    print(f"Trip start model accuracy: {start_accuracy:.3f}")
    
    # Train trip end model
    print("Training trip end detection model...")
    y_end = df['trip_end_label']
    X_train, X_test, y_end_train, y_end_test = train_test_split(
        X, y_end, test_size=0.2, random_state=42, stratify=y_end
    )
    
    end_model = RandomForestClassifier(
        n_estimators=100,
        max_depth=10,
        random_state=42,
        class_weight='balanced'
    )
    end_model.fit(X_train, y_end_train)
    
    end_accuracy = end_model.score(X_test, y_end_test)
    print(f"Trip end model accuracy: {end_accuracy:.3f}")
    
    # Train scaler
    print("Training feature scaler...")
    scaler = StandardScaler()
    scaler.fit(X)
    
    # Save models
    os.makedirs("app/ml_models", exist_ok=True)
    joblib.dump(start_model, "app/ml_models/trip_start_model.pkl")
    joblib.dump(end_model, "app/ml_models/trip_end_model.pkl")
    joblib.dump(scaler, "app/ml_models/trip_detection_scaler.pkl")
    
    print("Models saved to app/ml_models/")
    
    # Feature importance
    print("\nTrip Start Model - Top 10 Important Features:")
    feature_importance = pd.DataFrame({
        'feature': feature_cols,
        'importance': start_model.feature_importances_
    }).sort_values('importance', ascending=False)
    
    for i, row in feature_importance.head(10).iterrows():
        print(f"  {row['feature']}: {row['importance']:.3f}")
    
    print("\nTrip End Model - Top 10 Important Features:")
    feature_importance = pd.DataFrame({
        'feature': feature_cols,
        'importance': end_model.feature_importances_
    }).sort_values('importance', ascending=False)
    
    for i, row in feature_importance.head(10).iterrows():
        print(f"  {row['feature']}: {row['importance']:.3f}")
    
    return start_model, end_model, scaler

if __name__ == "__main__":
    train_trip_detection_models()
