import asyncio
import json
import logging
import time
from typing import Set
from fastapi import WebSocket, WebSocketDisconnect
from app.config import settings
from app.models.schemas import UnifiedTelemetryFrame
from app.services.system_service import system_service
from app.services.audio_service import audio_service
from app.services.media_service import media_service
from app.services.display_service import display_service

logger = logging.getLogger("pc_control.websocket")

class WebSocketManager:
    def __init__(self):
        self._active_connections: Set[WebSocket] = set()
        self._is_running = False
        self._ticker_task: asyncio.Task | None = None
        self._last_frame: UnifiedTelemetryFrame | None = None

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self._active_connections.add(websocket)
        client_ip = websocket.client.host if websocket.client else "127.0.0.1"
        try:
            from app.services.audit_service import audit_service
            audit_service.record_event("client_connected_telemetry", client_ip)
        except Exception:
            pass
        logger.info(f"WebSocket client connected from {client_ip}. Total clients: {len(self._active_connections)}")
        
        # Send immediate initial frame if available
        if self._last_frame:
            try:
                await websocket.send_text(self._last_frame.model_dump_json())
            except Exception:
                pass

    def disconnect(self, websocket: WebSocket):
        self._active_connections.discard(websocket)
        client_ip = websocket.client.host if websocket.client else "127.0.0.1"
        try:
            from app.services.audit_service import audit_service
            audit_service.record_event("client_disconnected", client_ip, {"channel": "telemetry"})
        except Exception:
            pass
        logger.info(f"WebSocket client disconnected: {client_ip}. Remaining clients: {len(self._active_connections)}")

    async def start_broadcaster(self):
        if not self._is_running:
            self._is_running = True
            self._ticker_task = asyncio.create_task(self._broadcast_loop())
            logger.info("Telemetry WebSocket broadcaster started.")

    async def stop_broadcaster(self):
        self._is_running = False
        if self._ticker_task:
            self._ticker_task.cancel()
            try:
                await self._ticker_task
            except asyncio.CancelledError:
                pass
        logger.info("Telemetry WebSocket broadcaster stopped.")

    async def get_current_frame(self) -> UnifiedTelemetryFrame:
        sys_telemetry = system_service.get_telemetry()
        audio_stat = audio_service.get_status()
        media_stat = await media_service.get_media_status()
        display_stat = display_service.get_status()
        
        frame = UnifiedTelemetryFrame(
            timestamp_ms=int(time.time() * 1000),
            pc_name=sys_telemetry.hostname,
            system=sys_telemetry,
            audio=audio_stat,
            media=media_stat,
            display=display_stat
        )
        self._last_frame = frame
        return frame

    async def _broadcast_loop(self):
        interval = settings.TELEMETRY_INTERVAL_MS / 1000.0
        while self._is_running:
            start_time = time.time()
            if self._active_connections:
                try:
                    frame = await self.get_current_frame()
                    payload_json = frame.model_dump_json()
                    
                    # Broadcast to all connected clients
                    dead_sockets = set()
                    for ws in list(self._active_connections):
                        try:
                            await ws.send_text(payload_json)
                        except (WebSocketDisconnect, RuntimeError, Exception):
                            dead_sockets.add(ws)

                    for ws in dead_sockets:
                        self.disconnect(ws)
                except Exception as e:
                    logger.error(f"Error in telemetry broadcast tick: {e}")

            elapsed = time.time() - start_time
            sleep_duration = max(0.01, interval - elapsed)
            await asyncio.sleep(sleep_duration)

ws_manager = WebSocketManager()
