from fastapi import APIRouter, Depends, HTTPException, Response
from app.core.security import verify_api_key
from app.services.media_service import media_service
from app.models.schemas import MediaStatus, MediaActionRequest, ApiResponse

router = APIRouter(prefix="/api/media", tags=["Media"])

@router.get("/now-playing", response_model=MediaStatus, dependencies=[Depends(verify_api_key)])
async def get_now_playing():
    """Get current Windows media playback metadata and transport state."""
    return await media_service.get_media_status()

@router.get("/thumbnail")
async def get_media_thumbnail():
    """Get album artwork/thumbnail image bytes of currently playing media."""
    thumb_bytes = media_service.get_cached_thumbnail()
    if not thumb_bytes:
        raise HTTPException(status_code=404, detail="No thumbnail available for active track")
    # Return raw image stream
    return Response(content=thumb_bytes, media_type="image/jpeg")

@router.post("/control", response_model=ApiResponse, dependencies=[Depends(verify_api_key)])
async def control_media(req: MediaActionRequest):
    """Execute playback action: play, pause, toggle, next, previous, seek."""
    success = await media_service.execute_control(req.action, req.position_ms)
    if not success:
        raise HTTPException(status_code=500, detail=f"Failed to execute media control '{req.action}'")
    return ApiResponse(success=True, message=f"Media control '{req.action}' executed successfully")
