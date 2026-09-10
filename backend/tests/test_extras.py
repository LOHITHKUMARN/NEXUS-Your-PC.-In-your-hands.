from fastapi.testclient import TestClient
from unittest.mock import patch
from app.main import app
from app.config import settings
from app.services.extras_service import extras_service
from app.services.audit_service import audit_service

client = TestClient(app)

def test_extras_service_open_url_normalization():
    # Empty string should return False
    assert extras_service.open_url("") is False
    assert extras_service.open_url("   ") is False

    # Mock ShellExecuteW to verify URL formatting without opening browser during automated tests
    with patch("ctypes.windll.shell32.ShellExecuteW", return_value=42) as mock_shell:
        # Standard URL
        assert extras_service.open_url("https://google.com") is True
        mock_shell.assert_called_with(0, "open", "https://google.com", None, None, 1)

        # Domain without protocol
        assert extras_service.open_url("github.com") is True
        mock_shell.assert_called_with(0, "open", "https://github.com", None, None, 1)

        # Search term without domain
        assert extras_service.open_url("youtube") is True
        mock_shell.assert_called_with(0, "open", "https://www.google.com/search?q=youtube", None, None, 1)


def test_open_url_endpoint_unauthorized():
    res = client.post("/api/extras/open-url", json={"url": "https://google.com"})
    assert res.status_code == 401


def test_open_url_endpoint_authorized_and_audited():
    with patch("app.services.extras_service.extras_service.open_url", return_value=True):
        res = client.post(
            "/api/extras/open-url",
            json={"url": "https://github.com"},
            headers={"X-API-Key": settings.API_KEY}
        )
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True

        # Verify audit log entry
        events = audit_service.get_events(limit=5)
        open_events = [e for e in events if e.get("event") == "open_url"]
        assert len(open_events) > 0
        assert open_events[0]["details"]["url"] == "https://github.com"
        assert open_events[0]["details"]["success"] is True
