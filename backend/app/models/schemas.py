from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

# --- System Telemetry Schemas ---
class DiskInfo(BaseModel):
    mount: str
    total_gb: float
    used_gb: float
    free_gb: float
    percent: float

class NetworkRate(BaseModel):
    download_kbps: float
    upload_kbps: float
    total_download_mb: float
    total_upload_mb: float

class GpuInfo(BaseModel):
    available: bool = False
    name: Optional[str] = None
    load_percent: Optional[float] = None
    temperature_c: Optional[float] = None
    vram_used_mb: Optional[float] = None
    vram_total_mb: Optional[float] = None

class BatteryInfo(BaseModel):
    present: bool = False
    percent: Optional[float] = None
    power_plugged: Optional[bool] = None
    seconds_left: Optional[int] = None

class SystemTelemetry(BaseModel):
    cpu_percent: float
    cpu_cores_percent: List[float] = Field(default_factory=list)
    cpu_freq_mhz: Optional[float] = None
    ram_percent: float
    ram_used_gb: float
    ram_total_gb: float
    gpu: GpuInfo = Field(default_factory=GpuInfo)
    disks: List[DiskInfo] = Field(default_factory=list)
    network: NetworkRate = Field(default_factory=lambda: NetworkRate(download_kbps=0, upload_kbps=0, total_download_mb=0, total_upload_mb=0))
    battery: BatteryInfo = Field(default_factory=BatteryInfo)
    hostname: str = ""
    uptime_seconds: int = 0

# --- Audio Schemas ---
class AudioDevice(BaseModel):
    id: str
    name: str
    is_default: bool = False
    state: str = "Active"

class AudioStatus(BaseModel):
    master_volume: int  # 0 to 100
    is_muted: bool
    devices: List[AudioDevice] = Field(default_factory=list)
    active_device_name: Optional[str] = None

# --- Media Schemas ---
class MediaStatus(BaseModel):
    has_media: bool = False
    is_playing: bool = False
    title: str = ""
    artist: str = ""
    album: str = ""
    source_app: str = ""
    position_ms: int = 0
    duration_ms: int = 0
    has_thumbnail: bool = False
    can_play_pause: bool = False
    can_next: bool = False
    can_previous: bool = False
    can_seek: bool = False

# --- Display Schemas ---
class DisplayStatus(BaseModel):
    brightness: int = 100
    display_count: int = 1

# --- Unified Live Telemetry Frame (Streamed via WebSocket) ---
class UnifiedTelemetryFrame(BaseModel):
    timestamp_ms: int
    pc_name: str
    system: SystemTelemetry
    audio: AudioStatus
    media: MediaStatus
    display: DisplayStatus

# --- App Launcher Schemas ---
class AppItem(BaseModel):
    id: str
    name: str
    command: str
    icon: str
    description: str
    is_running: bool = False

class RunningTask(BaseModel):
    pid: int
    name: str
    cpu_percent: float
    memory_mb: float

# --- Request Payloads ---
class SetVolumeRequest(BaseModel):
    volume: int = Field(ge=0, le=100)

class SetMuteRequest(BaseModel):
    mute: bool

class VolumeStepRequest(BaseModel):
    step: int = Field(description="Step delta, e.g. +5 or -5")

class SetDeviceRequest(BaseModel):
    device_id: str

class SetBrightnessRequest(BaseModel):
    brightness: int = Field(ge=0, le=100)

class MediaActionRequest(BaseModel):
    action: str = Field(description="play, pause, toggle, next, previous, seek")
    position_ms: Optional[int] = None

class PowerActionRequest(BaseModel):
    action: str = Field(description="lock, sleep, restart, shutdown")
    delay_seconds: int = 0
    force: bool = False

class ClipboardRequest(BaseModel):
    text: str

class OpenUrlRequest(BaseModel):
    url: str

class ToastRequest(BaseModel):
    title: str
    message: str

class ApiResponse(BaseModel):
    success: bool
    message: str
    data: Optional[Any] = None
