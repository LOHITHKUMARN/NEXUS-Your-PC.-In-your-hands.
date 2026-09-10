from fastapi import APIRouter, Depends, HTTPException
from app.core.security import verify_api_key
from app.services.display_service import display_service
from app.models.schemas import DisplayStatus, SetBrightnessRequest, ApiResponse

router = APIRouter(prefix="/api/display", tags=["Display"], dependencies=[Depends(verify_api_key)])

@router.get("", response_model=DisplayStatus)
async def get_display_status():
    """Get current screen brightness level."""
    return display_service.get_status()

@router.post("/brightness", response_model=ApiResponse)
async def set_brightness(req: SetBrightnessRequest):
    """Set screen brightness (0 to 100)."""
    success = display_service.set_brightness(req.brightness)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to adjust screen brightness")
    return ApiResponse(success=True, message=f"Brightness set to {req.brightness}%", data={"brightness": req.brightness})
