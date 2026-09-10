import logging
from typing import Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Header
from app.core.security import validate_ws_api_key
from app.services.input_service import input_service

logger = logging.getLogger("pc_control.router.input")

router = APIRouter(prefix="/api/input", tags=["Input"])

def extract_api_key_from_ws(websocket: WebSocket, api_key_query: str) -> str:
    """
    Extracts the API key from query param, X-API-Key header, or Sec-WebSocket-Protocol.
    Prevents API key exposure in access logs when headers are used.
    """
    if api_key_query:
        return api_key_query.strip()

    # Check custom headers
    x_api_key = websocket.headers.get("x-api-key")
    if x_api_key:
        return x_api_key.strip()

    # Check subprotocol (e.g. ['pc-control-auth', '<api_key>'])
    protocols = websocket.headers.get("sec-websocket-protocol", "")
    if protocols:
        parts = [p.strip() for p in protocols.split(",")]
        if len(parts) >= 2 and parts[0] == "pc-control-auth":
            return parts[1]

    return ""


@router.websocket("/ws")
async def input_websocket_endpoint(
    websocket: WebSocket,
    api_key: str = Query(default="")
):
    """
    Dedicated low-latency WebSocket endpoint for mouse, trackpad, and keyboard inputs.
    Operates independently from the telemetry socket to maintain sub-20ms latency.
    """
    client_ip = websocket.client.host if websocket.client else "127.0.0.1"
    token = extract_api_key_from_ws(websocket, api_key)

    if not validate_ws_api_key(token, client_ip):
        # Do not log full key in access logs
        logger.warning(f"Input WS connection rejected for client {client_ip}: unauthorized")
        await websocket.close(code=1008, reason="Unauthorized: Invalid API Key")
        return

    # Check if subprotocol was requested
    subprotocols = websocket.headers.get("sec-websocket-protocol", "")
    selected_subprotocol = None
    if "pc-control-auth" in subprotocols:
        selected_subprotocol = "pc-control-auth"

    await websocket.accept(subprotocol=selected_subprotocol)
    logger.info(f"Input WS client connected from {client_ip}")
    from app.services.audit_service import audit_service
    audit_service.record_event("client_connected_input", client_ip)

    try:
        while True:
            # Efficient async JSON packet read
            try:
                msg = await websocket.receive_json()
            except ValueError:
                continue

            event_type = msg.get("t")
            if not event_type:
                continue

            try:
                if event_type == "move":
                    dx = float(msg.get("dx", 0))
                    dy = float(msg.get("dy", 0))
                    sens = float(msg.get("sens", 1.0))
                    input_service.move_relative(dx, dy, sensitivity=sens)

                elif event_type == "click":
                    button = str(msg.get("button", "left"))
                    action = str(msg.get("action", "tap"))
                    input_service.mouse_button(button, action)

                elif event_type == "scroll":
                    dy = float(msg.get("dy", 0))
                    dx = float(msg.get("dx", 0))
                    natural = bool(msg.get("natural", True))
                    input_service.scroll(dy=dy, dx=dx, natural=natural)

                elif event_type == "key":
                    key_code = str(msg.get("code", ""))
                    action = str(msg.get("action", "tap"))
                    if key_code:
                        input_service.send_key(key_code, action=action)

                elif event_type == "text":
                    text_val = str(msg.get("value", ""))
                    if text_val:
                        input_service.send_text(text_val)

                elif event_type == "combo":
                    keys = msg.get("keys", [])
                    if isinstance(keys, list) and keys:
                        input_service.send_key_combo(keys)

                elif event_type == "ping":
                    await websocket.send_json({"t": "pong"})

            except Exception as e:
                # Catch per-event errors to ensure malformed packets don't tear down the connection
                logger.debug(f"Error dispatching input event {event_type}: {e}")

    except WebSocketDisconnect:
        logger.info(f"Input WS client disconnected: {client_ip}")
    except Exception as e:
        logger.warning(f"Input WS unexpected error with {client_ip}: {e}")
    finally:
        # SAFETY NET: Immediately release any held buttons or keys
        audit_service.record_event("client_disconnected", client_ip, {"channel": "input"})
        input_service.release_all()
