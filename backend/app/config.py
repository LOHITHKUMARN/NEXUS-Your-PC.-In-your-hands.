import os
import secrets
from pathlib import Path
from typing import List, Dict
from pydantic import BaseModel

class AppLauncherConfig(BaseModel):
    id: str
    name: str
    command: str
    icon: str
    description: str

class Settings:
    HOST: str = "0.0.0.0"
    PORT: int = 8765
    SERVICE_NAME: str = "PC Control Center"
    SERVICE_TYPE: str = "_pccontrol._tcp.local."
    
    # Base paths
    BASE_DIR: Path = Path(__file__).resolve().parent.parent
    DATA_DIR: Path = BASE_DIR / "data"
    CONFIG_FILE: Path = DATA_DIR / "config.json"
    
    # API Security
    API_KEY_FILE: Path = DATA_DIR / "api_key.txt"
    API_KEY: str = ""
    
    # Telemetry streaming tick rate in milliseconds
    TELEMETRY_INTERVAL_MS: int = 500
    
    # Default Allowlisted Applications
    DEFAULT_APPS: List[AppLauncherConfig] = [
        AppLauncherConfig(id="spotify", name="Spotify", command="spotify", icon="music", description="Spotify Music Player"),
        AppLauncherConfig(id="chrome", name="Google Chrome", command="chrome", icon="chrome", description="Web Browser"),
        AppLauncherConfig(id="discord", name="Discord", command="discord", icon="message-square", description="Chat & Voice"),
        AppLauncherConfig(id="steam", name="Steam", command="steam", icon="gamepad-2", description="Gaming Platform"),
        AppLauncherConfig(id="vscode", name="VS Code", command="code", icon="code", description="Visual Studio Code"),
        AppLauncherConfig(id="calc", name="Calculator", command="calc", icon="calculator", description="Windows Calculator"),
        AppLauncherConfig(id="taskmgr", name="Task Manager", command="taskmgr", icon="activity", description="Windows Task Manager"),
        AppLauncherConfig(id="notepad", name="Notepad", command="notepad", icon="file-text", description="Text Editor"),
        AppLauncherConfig(id="terminal", name="Windows Terminal", command="wt", icon="terminal", description="Terminal Console"),
    ]

    def __init__(self):
        self.DATA_DIR.mkdir(parents=True, exist_ok=True)
        self._api_key = self._load_or_create_api_key()

    @property
    def API_KEY(self) -> str:
        env_key = os.environ.get("PCC_API_KEY")
        if env_key:
            return env_key.strip()
        if self.API_KEY_FILE.exists():
            try:
                key = self.API_KEY_FILE.read_text(encoding="utf-8").strip()
                if key:
                    self._api_key = key
                    return key
            except Exception:
                pass
        return getattr(self, "_api_key", "")

    @API_KEY.setter
    def API_KEY(self, val: str):
        self._api_key = val

    def _load_or_create_api_key(self) -> str:
        env_key = os.environ.get("PCC_API_KEY")
        if env_key:
            return env_key.strip()
        
        if self.API_KEY_FILE.exists():
            try:
                key = self.API_KEY_FILE.read_text(encoding="utf-8").strip()
                if key:
                    return key
            except Exception:
                pass

        return self.rotate_api_key()

    def rotate_api_key(self) -> str:
        new_key = secrets.token_hex(8)
        self._api_key = new_key
        try:
            self.API_KEY_FILE.write_text(new_key, encoding="utf-8")
        except Exception:
            pass
        return new_key

    def get_pairing_uri(self) -> str:
        import socket
        import urllib.parse
        lan_ip = get_lan_ip()
        hostname = urllib.parse.quote(socket.gethostname())
        return f"pcc://{lan_ip}:{self.PORT}?key={self.API_KEY}&name={hostname}"

settings = Settings()

def get_lan_ip() -> str:
    """Gets the active local Wi-Fi or Ethernet IPv4 address of the PC."""
    import socket
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        try:
            return socket.gethostbyname(socket.gethostname())
        except Exception:
            return "127.0.0.1"
