import time
import threading
from collections import defaultdict
from typing import Dict, List, Tuple
from fastapi import Header, HTTPException, Query, Security, Request, status
from fastapi.security import APIKeyHeader, APIKeyQuery
from app.config import settings

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
api_key_query = APIKeyQuery(name="api_key", auto_error=False)

class AuthRateLimiter:
    """
    In-memory thread-safe rate limiter and brute-force protector.
    Locks out client IPs after multiple failed authentication attempts.
    """
    def __init__(self, max_failures: int = 5, window_seconds: int = 60, lockout_seconds: int = 300):
        self.max_failures = max_failures
        self.window_seconds = window_seconds
        self.lockout_seconds = lockout_seconds
        self._lock = threading.Lock()
        self._failures: Dict[str, List[float]] = defaultdict(list)
        self._lockouts: Dict[str, float] = {}

    def is_locked_out(self, client_ip: str) -> Tuple[bool, int]:
        """Returns (is_locked, remaining_seconds_locked)."""
        now = time.time()
        with self._lock:
            # Check active lockout
            if client_ip in self._lockouts:
                unlock_time = self._lockouts[client_ip]
                if now < unlock_time:
                    return True, int(unlock_time - now)
                else:
                    del self._lockouts[client_ip]
                    self._failures.pop(client_ip, None)
            return False, 0

    def record_failure(self, client_ip: str) -> Tuple[bool, int]:
        """Records a failed attempt. Returns (is_now_locked, remaining_seconds)."""
        now = time.time()
        with self._lock:
            # Prune old failures outside sliding window
            cutoff = now - self.window_seconds
            self._failures[client_ip] = [t for t in self._failures[client_ip] if t > cutoff]
            self._failures[client_ip].append(now)

            if len(self._failures[client_ip]) >= self.max_failures:
                self._lockouts[client_ip] = now + self.lockout_seconds
                return True, self.lockout_seconds
            return False, 0

    def record_success(self, client_ip: str):
        """Clears failure history on successful authentication."""
        with self._lock:
            self._failures.pop(client_ip, None)
            self._lockouts.pop(client_ip, None)

rate_limiter = AuthRateLimiter()

def _get_client_ip(request: Request) -> str:
    if request.client:
        return request.client.host
    return "127.0.0.1"

get_client_ip = _get_client_ip

async def verify_api_key(
    request: Request,
    x_api_key: str = Security(api_key_header),
    api_key_param: str = Security(api_key_query),
    authorization: str = Header(None)
) -> bool:
    """
    Verifies that the incoming request provides the valid API Key with brute-force protection.
    """
    client_ip = _get_client_ip(request)

    # If no API key configured (empty), allow in development
    if not settings.API_KEY:
        return True

    # Check key from header, query, or bearer token
    token = None
    if x_api_key:
        token = x_api_key.strip()
    elif api_key_param:
        token = api_key_param.strip()
    elif authorization and authorization.lower().startswith("bearer "):
        token = authorization[7:].strip()

    # If valid key provided, immediately clear any lockout and grant access
    if token and token == settings.API_KEY:
        rate_limiter.record_success(client_ip)
        return True

    from app.services.audit_service import audit_service

    # 1. If key is missing or invalid, check if IP is currently locked out
    locked, remaining = rate_limiter.is_locked_out(client_ip)
    if locked:
        audit_service.record_event("lockout_triggered", client_ip, {"remaining_seconds": remaining})
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many failed authentication attempts. Access locked for {remaining} seconds.",
            headers={"Retry-After": str(remaining)}
        )

    # Record failure & handle lockout
    is_now_locked, lock_duration = rate_limiter.record_failure(client_ip)
    if is_now_locked:
        audit_service.record_event("lockout_triggered", client_ip, {"lock_duration_seconds": lock_duration})
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many invalid authentication attempts. Client IP locked out for {lock_duration} seconds.",
            headers={"Retry-After": str(lock_duration)}
        )

    audit_service.record_event("auth_failed", client_ip, {"reason": "invalid_or_missing_token"})
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing API Key"
    )

def validate_ws_api_key(token: str, client_ip: str = "127.0.0.1") -> bool:
    """Validates API Key during WebSocket handshake with rate limiting."""
    if not settings.API_KEY:
        return True

    if token and token.strip() == settings.API_KEY:
        rate_limiter.record_success(client_ip)
        return True

    from app.services.audit_service import audit_service
    locked, rem = rate_limiter.is_locked_out(client_ip)
    if locked:
        audit_service.record_event("lockout_triggered", client_ip, {"channel": "ws", "remaining_seconds": rem})
        return False

    is_now_locked, dur = rate_limiter.record_failure(client_ip)
    if is_now_locked:
        audit_service.record_event("lockout_triggered", client_ip, {"channel": "ws", "lock_duration_seconds": dur})
    else:
        audit_service.record_event("auth_failed", client_ip, {"channel": "ws"})
    return False
