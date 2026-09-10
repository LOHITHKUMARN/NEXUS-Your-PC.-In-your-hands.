import socket
from fastapi import APIRouter, Depends, Request
from app.config import settings, get_lan_ip
from app.core.security import verify_api_key
from app.models.schemas import ApiResponse
from app.services.audit_service import audit_service

router = APIRouter(prefix="/api/auth", tags=["Auth"])

@router.get("/verify")
async def verify_auth(valid: bool = Depends(verify_api_key)):
    """Verifies that the client has a valid API key."""
    return {
        "authenticated": True,
        "hostname": socket.gethostname(),
        "api_key": settings.API_KEY
    }

@router.post("/rotate-key", response_model=ApiResponse, dependencies=[Depends(verify_api_key)])
async def rotate_api_key(request: Request):
    """Generates a new random API key, persists it, and invalidates old keys."""
    client_ip = request.client.host if request.client else "127.0.0.1"
    new_key = settings.rotate_api_key()
    audit_service.record_event("key_rotated", client_ip)
    return ApiResponse(
        success=True,
        message="API Key rotated successfully",
        data={
            "api_key": new_key,
            "pairing_uri": settings.get_pairing_uri()
        }
    )

@router.get("/pairing-info", dependencies=[Depends(verify_api_key)])
async def get_pairing_info():
    """Returns pairing payload and URI for fast pairing."""
    return {
        "service": settings.SERVICE_NAME,
        "hostname": socket.gethostname(),
        "lan_ip": get_lan_ip(),
        "port": settings.PORT,
        "api_key": settings.API_KEY,
        "pairing_uri": settings.get_pairing_uri()
    }
