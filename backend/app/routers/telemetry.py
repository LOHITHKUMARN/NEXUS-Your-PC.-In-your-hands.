from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, Query
from app.core.security import verify_api_key, validate_ws_api_key
from app.core.websocket_manager import ws_manager
from app.models.schemas import UnifiedTelemetryFrame

router = APIRouter(prefix="/api/telemetry", tags=["Telemetry"])

@router.get("", response_model=UnifiedTelemetryFrame, dependencies=[Depends(verify_api_key)])
async def get_telemetry_snapshot():
    """Get a one-shot full system, audio, media, and display telemetry snapshot."""
    return await ws_manager.get_current_frame()

@router.websocket("/ws")
async def websocket_telemetry_endpoint(
    websocket: WebSocket,
    api_key: str = Query(default="")
):
    """
    Real-time WebSocket endpoint streaming unified telemetry at 500ms intervals.
    Requires valid api_key query parameter for authentication.
    """
    client_ip = websocket.client.host if websocket.client else "127.0.0.1"
    if not validate_ws_api_key(api_key, client_ip):
        await websocket.close(code=1008, reason="Unauthorized: Invalid API Key or Rate Limited")
        return

    await ws_manager.connect(websocket)
    try:
        while True:
            # Keep-alive receive loop (handles client ping/messages)
            msg = await websocket.receive_text()
            # If client sends a ping or custom command over WS
            if msg == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)
    except Exception:
        ws_manager.disconnect(websocket)
