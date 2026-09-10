from fastapi import APIRouter, Depends, HTTPException
from app.core.security import verify_api_key
from app.services.power_service import power_service
from app.models.schemas import PowerActionRequest, ApiResponse

router = APIRouter(prefix="/api/power", tags=["Power"], dependencies=[Depends(verify_api_key)])

@router.post("/action", response_model=ApiResponse)
async def execute_power_action(req: PowerActionRequest):
    """
    Execute power action: lock, sleep, restart, shutdown, display_off.
    """
    action = req.action.lower()
    if action == "lock":
        success, msg = power_service.lock_workstation()
    elif action == "sleep":
        success, msg = power_service.sleep_system()
    elif action == "display_off" or action == "screen_off":
        success, msg = power_service.turn_off_display()
    elif action == "display_on" or action == "screen_on":
        success, msg = power_service.turn_on_display()
    elif action == "restart":
        success, msg = power_service.restart_pc(req.delay_seconds, req.force)
    elif action == "shutdown":
        success, msg = power_service.shutdown_pc(req.delay_seconds, req.force)
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported power action: {req.action}")

    if not success:
        raise HTTPException(status_code=500, detail=msg)
    return ApiResponse(success=True, message=msg)

@router.post("/cancel", response_model=ApiResponse)
async def cancel_scheduled_power_action():
    """Abort a scheduled restart or shutdown."""
    success, msg = power_service.abort_shutdown()
    if not success:
        raise HTTPException(status_code=500, detail=msg)
    return ApiResponse(success=True, message=msg)
