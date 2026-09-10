from fastapi import APIRouter, Depends, HTTPException
from app.core.security import verify_api_key
from app.services.audio_service import audio_service
from app.models.schemas import (
    AudioStatus,
    SetVolumeRequest,
    SetMuteRequest,
    VolumeStepRequest,
    SetDeviceRequest,
    ApiResponse
)

router = APIRouter(prefix="/api/audio", tags=["Audio"], dependencies=[Depends(verify_api_key)])

@router.get("", response_model=AudioStatus)
async def get_audio_status():
    """Get current master volume, mute state, and audio device list."""
    return audio_service.get_status()

@router.post("/volume", response_model=ApiResponse)
async def set_volume(req: SetVolumeRequest):
    """Set master volume percentage (0 to 100)."""
    success = audio_service.set_volume(req.volume)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to adjust master volume")
    return ApiResponse(success=True, message=f"Volume set to {req.volume}%", data={"volume": req.volume})

@router.post("/step", response_model=ApiResponse)
async def step_volume(req: VolumeStepRequest):
    """Nudge volume up or down by step delta (e.g. +5 or -5)."""
    new_vol = audio_service.step_volume(req.step)
    return ApiResponse(success=True, message=f"Volume stepped to {new_vol}%", data={"volume": new_vol})

@router.post("/mute", response_model=ApiResponse)
async def set_mute(req: SetMuteRequest):
    """Set mute state (true or false)."""
    success = audio_service.set_mute(req.mute)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to set mute state")
    return ApiResponse(success=True, message=f"Mute set to {req.mute}", data={"is_muted": req.mute})

@router.post("/mute/toggle", response_model=ApiResponse)
async def toggle_mute():
    """Toggle mute state."""
    new_state = audio_service.toggle_mute()
    return ApiResponse(success=True, message=f"Mute toggled to {new_state}", data={"is_muted": new_state})

@router.post("/device", response_model=ApiResponse)
async def set_audio_device(req: SetDeviceRequest):
    """Switch default Windows audio output device using COM IPolicyConfig."""
    success = audio_service.switch_device(req.device_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to switch audio output device")
    return ApiResponse(success=True, message="Audio output device switched successfully")
