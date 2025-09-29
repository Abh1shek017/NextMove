# Test script for OTP endpoints
import requests
import json

BASE_URL = "http://localhost:8001"

def test_send_otp():
    """Test sending OTP"""
    url = f"{BASE_URL}/auth/send_otp"
    data = {"phone_number": "+919876543210"}
    
    try:
        response = requests.post(url, json=data)
        print(f"Send OTP Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error sending OTP: {e}")
        return False

def test_verify_otp():
    """Test verifying OTP (will fail without real OTP)"""
    url = f"{BASE_URL}/auth/verify_otp"
    data = {
        "phone_number": "+919876543210",
        "otp": "123456"
    }
    
    try:
        response = requests.post(url, json=data)
        print(f"Verify OTP Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code in [200, 400, 404]  # 404 is expected for new users
    except Exception as e:
        print(f"Error verifying OTP: {e}")
        return False

def test_signup():
    """Test user signup"""
    url = f"{BASE_URL}/auth/signup"
    data = {
        "phone_number": "+919876543210",
        "name": "Test User",
        "age_group": "26-35",
        "gender": "Male",
        "occupation": "Software Engineer",
        "income_group": "₹40,000 - ₹60,000"
    }
    
    try:
        response = requests.post(url, json=data)
        print(f"Signup Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error in signup: {e}")
        return False

if __name__ == "__main__":
    print("Testing NextMove OTP System...")
    print("=" * 50)
    
    print("\n1. Testing Send OTP...")
    test_send_otp()
    
    print("\n2. Testing Verify OTP...")
    test_verify_otp()
    
    print("\n3. Testing Signup...")
    test_signup()
    
    print("\n" + "=" * 50)
    print("Test completed!")
