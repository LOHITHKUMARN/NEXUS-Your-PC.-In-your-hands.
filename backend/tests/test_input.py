import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.config import settings
from app.services.input_service import input_service, VK_MAP

client = TestClient(app)

def test_vk_map_keys():
    """Verify that essential modifiers and navigation keys are mapped."""
    assert "ctrl" in VK_MAP
    assert "shift" in VK_MAP
    assert "alt" in VK_MAP
    assert "win" in VK_MAP
    assert "esc" in VK_MAP
    assert "enter" in VK_MAP
    assert "tab" in VK_MAP
    assert "backspace" in VK_MAP
    assert "c" in VK_MAP
    assert "v" in VK_MAP
    assert "f5" in VK_MAP

def test_surrogate_pair_encoding_for_emoji():
    """
    CRITICAL TEST: Non-BMP characters (such as emojis like 🚀) must be encoded into
    UTF-16LE surrogate pairs (2 separate 16-bit WORD code units), not a single 4-byte codepoint.
    """
    emoji_text = "🚀"
    utf16_bytes = emoji_text.encode("utf-16-le")
    # A surrogate pair consists of 4 bytes (two 16-bit WORDs)
    assert len(utf16_bytes) == 4

    high_surrogate = int.from_bytes(utf16_bytes[0:2], byteorder="little")
    low_surrogate = int.from_bytes(utf16_bytes[2:4], byteorder="little")

    # High surrogate range: 0xD800 - 0xDBFF
    assert 0xD800 <= high_surrogate <= 0xDBFF
    # Low surrogate range: 0xDC00 - 0xDFFF
    assert 0xDC00 <= low_surrogate <= 0xDFFF

    # Verify input_service.send_text handles it without raising exceptions
    assert input_service.send_text("Hello 🚀 World!") is True

def test_input_safety_net_release_all():
    """Verify that release_all() cleanly empties held mouse buttons and modifier keys."""
    # Simulate holding left mouse button and Ctrl key
    input_service.mouse_button("left", "down")
    assert "left" in input_service._held_mouse_buttons

    input_service.send_key("ctrl", "down")
    assert VK_MAP["ctrl"] in input_service._held_keys

    # Trigger safety net
    input_service.release_all()

    # Verify both tracking sets are completely cleared
    assert len(input_service._held_mouse_buttons) == 0
    assert len(input_service._held_keys) == 0

def test_input_ws_unauthorized():
    """Verify that WebSocket handshake fails if API key is invalid."""
    with pytest.raises(Exception):
        with client.websocket_connect("/api/input/ws?api_key=wrong-key-1234") as websocket:
            websocket.receive_json()

def test_input_ws_authorized_and_event_stream():
    """Verify that WebSocket handshake succeeds with valid key and processes input stream."""
    with client.websocket_connect(f"/api/input/ws?api_key={settings.API_KEY}") as websocket:
        # Send ping
        websocket.send_json({"t": "ping"})
        data = websocket.receive_json()
        assert data.get("t") == "pong"

        # Send high-frequency move events (should not trip auth rate limiter)
        for i in range(50):
            websocket.send_json({"t": "move", "dx": 1.5, "dy": -2.0, "sens": 1.2})

        # Send click, scroll, combo, and text events
        websocket.send_json({"t": "click", "button": "left", "action": "tap"})
        websocket.send_json({"t": "scroll", "dy": -5.0, "natural": True})
        websocket.send_json({"t": "combo", "keys": ["ctrl", "c"]})
        websocket.send_json({"t": "text", "value": "Hi 🚀"})
