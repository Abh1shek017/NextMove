# tests/test_end_to_end.py
import pytest
import httpx
from datetime import datetime, timedelta
import json

BASE_URL = "http://localhost:8000"

@pytest.fixture
async def client():
    async with httpx.AsyncClient(base_url=BASE_URL) as client:
        yield client

@pytest.mark.asyncio
async def test_complete_trip_flow(client):
    # Step 1: Start trip
    start_response = await client.post("/trip/start", json={
        "user_id": "test_user_123",
        "start_time": datetime.utcnow().isoformat()
    })
    assert start_response.status_code == 200
    trip_data = start_response.json()
    trip_id = trip_data["trip_id"]
    
    # Step 2: Send GPS batch
    gps_batch = []
    base_time = datetime.utcnow()
    for i in range(10):
        gps_batch.append({
            "trip_id": trip_id,
            "latitude": 37.7749 + (i * 0.001),
            "longitude": -122.4194 + (i * 0.001),
            "recorded_at": (base_time + timedelta(seconds=i*30)).isoformat()
        })
    
    gps_response = await client.post("/gps/batch", json=gps_batch)
    assert gps_response.status_code == 200
    
    # Step 3: Stop trip
    stop_response = await client.post(f"/trip/stop/{trip_id}")
    assert stop_response.status_code == 200
    
    # Step 4: Predict mode
    predict_response = await client.get(f"/trip/predict_mode/{trip_id}")
    assert predict_response.status_code == 200
    prediction = predict_response.json()
    assert "predicted_mode" in prediction
    assert "confidence" in prediction
    
    # Step 5: Confirm prediction
    confirm_response = await client.post(f"/trip/confirm/{trip_id}", json={
        "actual_mode": "walking"  # or whatever you want to test
    })
    assert confirm_response.status_code == 200
    
    print(f"✅ Complete trip flow successful! Trip ID: {trip_id}")
    print(f"Prediction: {prediction}")

if __name__ == "__main__":
    import asyncio
    asyncio.run(test_complete_trip_flow(httpx.AsyncClient(base_url=BASE_URL)))