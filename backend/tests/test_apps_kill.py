import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch
from app.main import app
from app.config import settings
from app.services.launcher_service import launcher_service
from app.services.audit_service import audit_service

client = TestClient(app)

def test_kill_task_unauthorized():
    response = client.post("/api/apps/tasks/99999/kill")
    assert response.status_code in (401, 403)

def test_kill_task_authorized_mocked():
    headers = {"X-API-Key": settings.API_KEY}
    with patch.object(launcher_service, "kill_task", return_value=True) as mock_kill:
        response = client.post("/api/apps/tasks/12345/kill", headers=headers)
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "12345" in data["message"]
        mock_kill.assert_called_once_with(12345, client_ip="testclient")

def test_kill_task_failure_mocked():
    headers = {"X-API-Key": settings.API_KEY}
    with patch.object(launcher_service, "kill_task", return_value=False):
        response = client.post("/api/apps/tasks/99999/kill", headers=headers)
        assert response.status_code == 400
        data = response.json()
        assert "Failed to terminate" in data["detail"]

def test_launcher_service_kill_records_audit():
    with patch("psutil.Process") as mock_proc:
        mock_instance = MagicMock()
        mock_instance.name.return_value = "notepad.exe"
        mock_proc.return_value = mock_instance

        success = launcher_service.kill_task(4444, client_ip="192.168.29.184")
        assert success is True
        mock_instance.terminate.assert_called_once()

        # Check audit event was recorded
        events = audit_service.get_events(limit=5)
        assert any(e["event"] == "process_killed" and e.get("details", {}).get("pid") == 4444 for e in events)
