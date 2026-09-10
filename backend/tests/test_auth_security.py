import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.config import settings
from app.core.security import rate_limiter

client = TestClient(app)

def test_auth_pairing_info():
    res = client.get("/api/auth/pairing-info", headers={"X-API-Key": settings.API_KEY})
    assert res.status_code == 200
    data = res.json()
    assert "pairing_uri" in data
    assert data["api_key"] == settings.API_KEY
    assert data["pairing_uri"].startswith("pcc://")

def test_auth_rotate_key():
    old_key = settings.API_KEY
    res = client.post("/api/auth/rotate-key", headers={"X-API-Key": old_key})
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    new_key = data["data"]["api_key"]
    assert new_key != old_key
    assert settings.API_KEY == new_key

    # Old key is now invalid
    res_old = client.get("/api/auth/verify", headers={"X-API-Key": old_key})
    assert res_old.status_code == 401

    # New key works
    res_new = client.get("/api/auth/verify", headers={"X-API-Key": new_key})
    assert res_new.status_code == 200

    # Restore key so running test suite doesn't rotate developer's actual pairing key
    settings.API_KEY = old_key
    if settings.API_KEY_FILE.exists():
        settings.API_KEY_FILE.write_text(old_key, encoding="utf-8")

def test_rate_limiter_lockout():
    test_ip = "192.0.2.100"
    rate_limiter.record_success(test_ip) # Clear
    
    # 4 failures - not locked
    for _ in range(4):
        locked, _ = rate_limiter.record_failure(test_ip)
        assert locked is False

    # 5th failure - locks out
    locked, duration = rate_limiter.record_failure(test_ip)
    assert locked is True
    assert duration > 0

    # Active lockout check
    is_locked, rem = rate_limiter.is_locked_out(test_ip)
    assert is_locked is True
    assert rem > 0

    # Success clears
    rate_limiter.record_success(test_ip)
    is_locked, _ = rate_limiter.is_locked_out(test_ip)
    assert is_locked is False
