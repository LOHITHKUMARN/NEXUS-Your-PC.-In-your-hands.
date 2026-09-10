import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.config import settings
from app.services.audit_service import AuditService, audit_service
from app.services.system_service import system_service

client = TestClient(app)

def test_audit_service_recording_and_limit(tmp_path, monkeypatch):
    """Verifies that AuditService limits entries to max_entries and writes through."""
    custom_audit = AuditService(max_entries=5)
    custom_audit._log_file = tmp_path / "test_audit.json"

    for i in range(10):
        custom_audit.record_event(f"event_{i}", "192.168.1.100", {"index": i})

    events = custom_audit.get_events(limit=10)
    assert len(events) == 5
    # Should be newest first
    assert events[0]["event"] == "event_9"
    assert events[-1]["event"] == "event_5"

    # Verify write-through file exists and contains 5 items
    assert custom_audit._log_file.exists()
    import json
    data = json.loads(custom_audit._log_file.read_text())
    assert len(data) == 5

def test_audit_log_endpoint_unauthorized():
    response = client.get("/api/system/audit-log")
    assert response.status_code in (401, 403)

def test_audit_log_endpoint_authorized():
    headers = {"X-API-Key": settings.API_KEY}
    audit_service.record_event("test_endpoint_event", "127.0.0.1")
    response = client.get("/api/system/audit-log?limit=5", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert "count" in data
    assert "events" in data
    assert any(e["event"] == "test_endpoint_event" for e in data["events"])

def test_mac_address_in_discovery_and_root():
    mac = system_service.get_mac_address()
    assert isinstance(mac, str)
    if mac:
        # Should be colon-separated hex MAC (e.g. AA:BB:CC:DD:EE:FF)
        assert len(mac.split(":")) == 6

    # Check root status
    res_root = client.get("/")
    assert res_root.status_code == 200
    assert "mac_address" in res_root.json()

    # Check discovery info
    res_disc = client.get("/api/discovery/info")
    assert res_disc.status_code == 200
    assert "mac_address" in res_disc.json()
