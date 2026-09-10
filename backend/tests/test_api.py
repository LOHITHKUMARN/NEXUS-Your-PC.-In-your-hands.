import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.config import settings

client = TestClient(app)

def test_root_status():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "online"
    assert data["port"] == settings.PORT

def test_auth_unauthorized():
    response = client.get("/api/telemetry", headers={"X-API-Key": "invalid-key-12345"})
    assert response.status_code == 401

def test_auth_authorized():
    response = client.get("/api/telemetry", headers={"X-API-Key": settings.API_KEY})
    assert response.status_code == 200
    data = response.json()
    assert "system" in data
    assert "audio" in data
    assert "media" in data
    assert "display" in data
    assert "cpu_percent" in data["system"]
    assert "ram_percent" in data["system"]

def test_audio_status():
    response = client.get("/api/audio", headers={"X-API-Key": settings.API_KEY})
    assert response.status_code == 200
    data = response.json()
    assert "master_volume" in data
    assert "is_muted" in data
    assert "devices" in data

def test_display_status():
    response = client.get("/api/display", headers={"X-API-Key": settings.API_KEY})
    assert response.status_code == 200
    data = response.json()
    assert "brightness" in data

def test_apps_list():
    response = client.get("/api/apps", headers={"X-API-Key": settings.API_KEY})
    assert response.status_code == 200
    apps = response.json()
    assert isinstance(apps, list)
    assert len(apps) > 0
    assert any(a["id"] == "spotify" for a in apps)

def test_running_tasks():
    response = client.get("/api/apps/tasks", headers={"X-API-Key": settings.API_KEY})
    assert response.status_code == 200
    tasks = response.json()
    assert isinstance(tasks, list)
