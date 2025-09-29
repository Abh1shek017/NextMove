# backend/train_model.py
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier
import joblib

# Generate synthetic dataset
np.random.seed(42)
n_samples = 2000

data = []
for _ in range(n_samples):
    mode = np.random.choice(["walk", "bike", "bus", "car"])
    
    if mode == "walk":
        avg_speed = np.random.uniform(3, 6)
        max_speed = avg_speed + np.random.uniform(0, 2)
        std_speed = np.random.uniform(0, 1)
        stop_freq = np.random.randint(0, 3)
        distance = np.random.uniform(0.5, 3)
    elif mode == "bike":
        avg_speed = np.random.uniform(10, 20)
        max_speed = avg_speed + np.random.uniform(0, 5)
        std_speed = np.random.uniform(0, 3)
        stop_freq = np.random.randint(0, 5)
        distance = np.random.uniform(2, 15)
    elif mode == "bus":
        avg_speed = np.random.uniform(20, 40)
        max_speed = avg_speed + np.random.uniform(0, 10)
        std_speed = np.random.uniform(5, 15)
        stop_freq = np.random.randint(5, 15)
        distance = np.random.uniform(5, 30)
    else:  # car
        avg_speed = np.random.uniform(30, 80)
        max_speed = avg_speed + np.random.uniform(0, 30)
        std_speed = np.random.uniform(10, 25)
        stop_freq = np.random.randint(0, 5)
        distance = np.random.uniform(5, 100)

    data.append({
        "avg_speed": avg_speed,
        "max_speed": max_speed,
        "std_speed": std_speed,
        "avg_acceleration": np.random.uniform(0.5, 3.0),
        "stop_frequency": stop_freq,
        "distance_km": distance,
        "mode_label": mode
    })

df = pd.DataFrame(data)

# Features & labels
X = df[["avg_speed", "max_speed", "std_speed", "avg_acceleration", "stop_frequency", "distance_km"]]
y = df["mode_label"]

# Encode labels into numbers
label_encoder = LabelEncoder()
y_encoded = label_encoder.fit_transform(y)

# Split dataset
X_train, X_test, y_train, y_test = train_test_split(X, y_encoded, test_size=0.2, random_state=42)

# Train model
model = XGBClassifier(
    n_estimators=100,
    max_depth=6,
    learning_rate=0.1,
    random_state=42,
    use_label_encoder=False,
    eval_metric="mlogloss"
)
model.fit(X_train, y_train)

# Save model and label encoder
joblib.dump(model, "app/ml_models/mode_model.pkl")
joblib.dump(label_encoder, "app/ml_models/label_encoder.pkl")

print("Model trained and saved to app/ml_models/mode_model.pkl")
print("Label encoder saved to app/ml_models/label_encoder.pkl")
print(f"Accuracy on test set: {model.score(X_test, y_test):.2f}")
