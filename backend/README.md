# NextMove Backend Setup

## Environment Variables Required

Create a `.env` file in the backend directory with the following variables:

```bash
# Database Configuration
DATABASE_URL=postgresql://username:password@localhost:5432/nextmove_db

# JWT Configuration
SECRET_KEY=your-super-secret-key-change-this-in-production
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30

# Twilio Configuration (Get these from https://console.twilio.com/)
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_VERIFY_SERVICE_SID=your_twilio_verify_service_sid
```

## Twilio Setup

1. Go to [Twilio Console](https://console.twilio.com/)
2. Create a new account or sign in
3. Get your Account SID and Auth Token from the dashboard
4. Create a Verify Service:
   - Go to Verify > Services
   - Create a new service
   - Copy the Service SID
5. Add these credentials to your `.env` file

## API Endpoints

### Authentication
- `POST /auth/send_otp` - Send OTP to phone number
- `POST /auth/verify_otp` - Verify OTP and get JWT token
- `POST /auth/signup` - Complete user profile setup

### Trips
- `POST /trip/start` - Start a new trip
- `POST /trip/stop` - Stop current trip
- `POST /trip/confirm/{trip_id}` - Confirm trip details

## Running the Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`
Documentation will be available at `http://localhost:8000/docs`


