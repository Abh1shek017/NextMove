# app/main.py
from fastapi import FastAPI

app = FastAPI(
    title="NextMove API",
    description="Transport mode prediction for urban mobility",
    version="0.1.0"
)

@app.get("/")
async def root():
    return {"message": "Welcome to NextMove!"}

@app.get("/health")
async def health_check():
    return {"status": "OK"}