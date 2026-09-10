import json
import logging
import threading
from collections import deque
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Dict, Optional, Any
from app.config import settings

logger = logging.getLogger("pc_control.audit")

class AuditService:
    """
    In-memory and write-through persistent security and session activity audit logger.
    Maintains a rolling 100-event log stored in backend/data/audit_log.json.
    """
    def __init__(self, max_entries: int = 100):
        self._max_entries = max_entries
        self._lock = threading.Lock()
        self._events = deque(maxlen=max_entries)
        self._log_file: Path = settings.DATA_DIR / "audit_log.json"
        self._load_persisted_logs()

    def _load_persisted_logs(self):
        try:
            if self._log_file.exists():
                data = json.loads(self._log_file.read_text(encoding="utf-8"))
                if isinstance(data, list):
                    for item in data[-self._max_entries:]:
                        self._events.append(item)
                    logger.info(f"Loaded {len(self._events)} audit events from disk.")
        except Exception as e:
            logger.warning(f"Could not load persisted audit logs: {e}")

    def _persist(self):
        try:
            items = list(self._events)
            self._log_file.write_text(json.dumps(items, indent=2), encoding="utf-8")
        except Exception as e:
            logger.warning(f"Failed to persist audit log to disk: {e}")

    def record_event(
        self,
        event: str,
        client_ip: str = "127.0.0.1",
        details: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """
        Records an event and persists it immediately (write-through).
        event: e.g. 'auth_success', 'auth_failed', 'lockout_triggered',
                     'client_connected_telemetry', 'client_connected_input',
                     'client_disconnected', 'key_rotated', 'power_action', 'app_launched'
        """
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "event": event,
            "client_ip": client_ip,
            "details": details or {},
        }
        with self._lock:
            self._events.append(entry)
            self._persist()

        logger.info(f"Audit: [{event}] from {client_ip} - {details or ''}")
        return entry

    def get_events(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Returns the most recent events in reverse-chronological order (newest first)."""
        with self._lock:
            items = list(self._events)
        items.reverse()
        return items[:limit]

    def clear(self):
        """Clears all in-memory and persisted audit events."""
        with self._lock:
            self._events.clear()
            self._persist()


audit_service = AuditService()
