from typing import List
from fastapi import APIRouter, Depends, HTTPException, Path, Request
from app.core.security import verify_api_key, get_client_ip
from app.services.launcher_service import launcher_service
from app.models.schemas import AppItem, RunningTask, ApiResponse

router = APIRouter(prefix="/api/apps", tags=["Apps"], dependencies=[Depends(verify_api_key)])

@router.get("", response_model=List[AppItem])
async def list_launchable_apps():
    """Get list of allowlisted applications and their running status."""
    return launcher_service.get_apps()

@router.post("/launch/{app_id}", response_model=ApiResponse)
async def launch_application(app_id: str = Path(..., description="ID of the allowlisted application")):
    """Launch an allowlisted application on the host PC."""
    success = launcher_service.launch_app(app_id)
    if not success:
        raise HTTPException(status_code=400, detail=f"Failed to launch application with ID '{app_id}'")
    return ApiResponse(success=True, message=f"Application '{app_id}' launched successfully")

@router.get("/tasks", response_model=List[RunningTask])
async def get_running_tasks():
    """Get top running processes/tasks sorted by memory consumption."""
    return launcher_service.get_top_tasks()

@router.post("/tasks/{pid}/kill", response_model=ApiResponse)
async def kill_running_task(
    request: Request,
    pid: int = Path(..., description="Process ID to terminate")
):
    """Terminates an active process on the host PC."""
    client_ip = get_client_ip(request)
    success = launcher_service.kill_task(pid, client_ip=client_ip)
    if not success:
        raise HTTPException(status_code=400, detail=f"Failed to terminate process with PID {pid}")
    return ApiResponse(success=True, message=f"Process {pid} terminated successfully")
