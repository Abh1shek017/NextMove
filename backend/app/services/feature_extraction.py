# app/services/feature_extraction.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text

async def extract_features(db: AsyncSession, trip_id: int) -> dict:
    # 1. Get all GPS logs for the trip
    result = await db.execute(
        text("""
            SELECT 
                speed,
                ST_X(location::geometry) as lon,
                ST_Y(location::geometry) as lat,
                timestamp
            FROM gps_logs 
            WHERE trip_id = :trip_id 
            ORDER BY timestamp
        """),
        {"trip_id": trip_id}
    )
    logs = result.fetchall()
    
    if not logs:
        return {}

    # --- Speed-based features ---
    speeds = [log.speed for log in logs if log.speed is not None]
    avg_speed = sum(speeds) / len(speeds) if speeds else 0.0
    max_speed = max(speeds) if speeds else 0.0
    std_speed = (sum((s - avg_speed) ** 2 for s in speeds) / len(speeds)) ** 0.5 if speeds else 0.0

    # --- Stop frequency (speed < 2 km/h for >30s) ---
    stop_count = 0
    i = 0
    while i < len(logs):
        if logs[i].speed is not None and logs[i].speed < 2.0:
            stop_start = logs[i].timestamp
            j = i
            while j < len(logs) and logs[j].speed is not None and logs[j].speed < 2.0:
                j += 1
            if j < len(logs):
                stop_duration = (logs[j].timestamp - stop_start).total_seconds()
                if stop_duration >= 30:
                    stop_count += 1
            i = j
        else:
            i += 1

    # --- Average acceleration ---
    if len(logs) < 2:
        avg_acceleration = 0.0
    else:
        accelerations = []
        for i in range(1, len(logs)):
            if logs[i].speed is not None and logs[i - 1].speed is not None:
                dt = (logs[i].timestamp - logs[i - 1].timestamp).total_seconds()
                if dt > 0:
                    acc = (logs[i].speed - logs[i - 1].speed) / dt  # km/h per second
                    accelerations.append(acc)
        avg_acceleration = sum(accelerations) / len(accelerations) if accelerations else 0.0

    # 2. Compute distance using PostGIS — FIXED QUERY
    distance_result = await db.execute(
        text("""
            WITH ordered_points AS (
                SELECT location::geometry AS geom
                FROM gps_logs
                WHERE trip_id = :trip_id
                ORDER BY timestamp
            )
            SELECT ST_Length(
                ST_MakeLine(geom)::geography
            ) / 1000 AS distance_km
            FROM ordered_points
        """),
        {"trip_id": trip_id}
    )
    distance_row = distance_result.fetchone()
    distance_km = distance_row.distance_km if distance_row and distance_row.distance_km is not None else 0.0

    # --- Final feature set ---
    return {
        "avg_speed": float(avg_speed),
        "max_speed": float(max_speed),
        "std_speed": float(std_speed),
        "avg_acceleration": float(avg_acceleration),
        "stop_frequency": stop_count,
        "distance_km": float(distance_km)
    }