from fastapi import APIRouter, Depends, HTTPException, Request
from app.core.security import verify_api_key, get_client_ip
from app.services.extras_service import extras_service
from app.services.audit_service import audit_service
from app.models.schemas import ClipboardRequest, OpenUrlRequest, ToastRequest, ApiResponse

router = APIRouter(prefix="/api/extras", tags=["Extras"], dependencies=[Depends(verify_api_key)])

@router.post("/clipboard", response_model=ApiResponse)
async def set_pc_clipboard(req: ClipboardRequest):
    """Copy text from mobile/tablet to PC clipboard."""
    success = extras_service.set_clipboard(req.text)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to copy text to PC clipboard")
    return ApiResponse(success=True, message="Text copied to PC clipboard")

@router.post("/open-url", response_model=ApiResponse)
async def open_url_on_pc(req: OpenUrlRequest, request: Request):
    """Open URL in default web browser on the PC."""
    client_ip = get_client_ip(request)
    success = extras_service.open_url(req.url)
    audit_service.record_event(
        "open_url",
        client_ip=client_ip,
        details={"url": req.url, "success": success}
    )
    if not success:
        raise HTTPException(status_code=500, detail="Failed to open URL on PC")
    return ApiResponse(success=True, message=f"URL opened on PC: {req.url}")

@router.post("/toast", response_model=ApiResponse)
async def show_toast_notification(req: ToastRequest):
    """Display a Windows toast notification from phone/tablet."""
    success = extras_service.show_toast(req.title, req.message)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to show toast notification")
    return ApiResponse(success=True, message="Toast notification sent")
