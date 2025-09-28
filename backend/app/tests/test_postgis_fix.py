# test_postgis_fix.py
import asyncio
import asyncpg
from typing import List, Tuple

async def test_distance_calculation():
    conn = await asyncpg.connect(
        host="localhost",
        port=5432,
        user="your_user",
        password="your_password",
        database="your_db"
    )
    
    # Test  Insert sample GPS points for a trip
    trip_id = "test_trip_001"
    gps_points = [
        (trip_id, -122.4194, 37.7749, "2024-01-01 10:00:00"),
        (trip_id, -122.4094, 37.7849, "2024-01-01 10:05:00"),
        (trip_id, -122.3994, 37.7949, "2024-01-01 10:10:00")
    ]
    
    # Insert test data
    await conn.execute("DELETE FROM gps_logs WHERE trip_id = $1", trip_id)
    await conn.executemany(
        "INSERT INTO gps_logs (trip_id, geom, recorded_at) VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326), $4)",
        gps_points
    )
    
    # Your CTE query (adjust as needed)
    query = """
    WITH ordered_points AS (
        SELECT 
            geom::geometry,
            recorded_at,
            ROW_NUMBER() OVER (ORDER BY recorded_at) as rn
        FROM gps_logs 
        WHERE trip_id = $1
        ORDER BY recorded_at
    ),
    line_geom AS (
        SELECT ST_MakeLine(geom ORDER BY rn) as line
        FROM ordered_points
    )
    SELECT 
        ST_Length(ST_Transform(line::geometry, 3857)) as distance_meters
    FROM line_geom
    WHERE line IS NOT NULL;
    """
    
    result = await conn.fetchrow(query, trip_id)
    print(f"Distance calculated: {result['distance_meters']} meters")
    
    await conn.close()

if __name__ == "__main__":
    asyncio.run(test_distance_calculation())