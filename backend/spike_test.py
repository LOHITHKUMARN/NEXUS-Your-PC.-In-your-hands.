import asyncio
import sys
import psutil

print("=== Python System Environment ===")
print("Python version:", sys.version)

# 1. System Telemetry Spike
print("\n--- 1. System Telemetry (psutil) ---")
cpu_pct = psutil.cpu_percent(interval=0.5)
cpu_count = psutil.cpu_count(logical=True)
mem = psutil.virtual_memory()
print(f"CPU Usage: {cpu_pct}% ({cpu_count} logical cores)")
print(f"RAM Usage: {mem.percent}% ({mem.used / (1024**3):.2f}GB / {mem.total / (1024**3):.2f}GB)")

# 2. GPU Telemetry Spike
print("\n--- 2. GPU Telemetry (pynvml / fallback) ---")
try:
    import pynvml
    pynvml.nvmlInit()
    device_count = pynvml.nvmlDeviceGetCount()
    print(f"NVIDIA GPU Count: {device_count}")
    for i in range(device_count):
        handle = pynvml.nvmlDeviceGetHandleByIndex(i)
        name = pynvml.nvmlDeviceGetName(handle)
        util = pynvml.nvmlDeviceGetUtilizationRates(handle)
        mem_info = pynvml.nvmlDeviceGetMemoryInfo(handle)
        temp = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
        print(f"  GPU {i} ({name}): Load={util.gpu}%, Temp={temp}°C, VRAM={mem_info.used/(1024**2):.0f}MB/{mem_info.total/(1024**2):.0f}MB")
    pynvml.nvmlShutdown()
except Exception as e:
    print(f"pynvml GPU query (or non-NVIDIA system): {e}")

# 3. Audio Control & Pycaw Spike
print("\n--- 3. Audio Control (pycaw & Windows Core Audio) ---")
try:
    from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
    from ctypes import cast, POINTER
    from comtypes import CLSCTX_ALL
    
    devices = AudioUtilities.GetSpeakers()
    interface = devices.Activate(IAudioEndpointVolume._iid_, CLSCTX_ALL, None)
    volume = cast(interface, POINTER(IAudioEndpointVolume))
    current_vol = volume.GetMasterVolumeLevelScalar()
    is_muted = volume.GetMute()
    print(f"Master Volume: {round(current_vol * 100)}%, Muted: {bool(is_muted)}")
except Exception as e:
    print(f"pycaw error: {e}")

# 4. Media Transport Spike (winsdk)
print("\n--- 4. Media Transport Control (winsdk) ---")
async def test_media():
    try:
        from winsdk.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as MediaManager
        manager = await MediaManager.request_async()
        current_session = manager.get_current_session()
        if current_session:
            source_id = current_session.source_app_user_model_id
            timeline = current_session.get_timeline_properties()
            playback_info = current_session.get_playback_info()
            status = playback_info.playback_status.name if playback_info else "Unknown"
            media_properties = await current_session.try_get_media_properties_async()
            title = media_properties.title if media_properties else "None"
            artist = media_properties.artist if media_properties else "None"
            print(f"Active Media Session: Source='{source_id}', Status={status}, Title='{title}', Artist='{artist}'")
            
            # Test thumbnail stream reference
            if media_properties and media_properties.thumbnail:
                from winsdk.windows.storage.streams import DataReader, Buffer, InputStreamOptions
                stream_ref = media_properties.thumbnail
                read_stream = await stream_ref.open_read_async()
                size = read_stream.size
                print(f"Media Thumbnail found: size={size} bytes")
            else:
                print("No thumbnail reference on active media properties.")
        else:
            print("No active media sessions currently playing on Windows.")
    except Exception as e:
        print(f"winsdk media test error: {e}")

asyncio.run(test_media())

# 5. Brightness Spike
print("\n--- 5. Screen Brightness Control ---")
try:
    import screen_brightness_control as sbc
    current_brightness = sbc.get_brightness()
    print(f"Current Screen Brightness: {current_brightness}%")
except Exception as e:
    print(f"screen_brightness_control error: {e}")
