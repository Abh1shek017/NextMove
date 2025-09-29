# app/utils/twilio_client.py
from twilio.rest import Client
from app.config import settings

client = Client(settings.twilio_account_sid, settings.twilio_auth_token)

def send_otp(phone_number: str):
    verification = client.verify.v2.services(
        settings.twilio_verify_service_sid
    ).verifications.create(to=phone_number, channel="sms")
    return verification.status

def verify_otp(phone_number: str, code: str):
    verification = client.verify.v2.services(
        settings.twilio_verify_service_sid
    ).verification_checks.create(to=phone_number, code=code)
    return verification.status == "approved"