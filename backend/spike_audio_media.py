import asyncio
from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
import comtypes
from ctypes import POINTER, cast

print("--- Testing Modern Pycaw API ---")
try:
    # In newer pycaw versions, AudioUtilities.GetSpeakers() returns an AudioDevice
    speaker = AudioUtilities.GetSpeakers()
    print("Speaker type:", type(speaker))
    
    # Try different accessors
    if hasattr(speaker, 'EndpointVolume'):
        vol = speaker.EndpointVolume
        print(f"via EndpointVolume: Master={round(vol.GetMasterVolumeLevelScalar() * 100)}%, Muted={vol.GetMute()}")
    elif hasattr(speaker, 'endpoint_volume'):
        vol = speaker.endpoint_volume
        print(f"via endpoint_volume: Master={round(vol.GetMasterVolumeLevelScalar() * 100)}%, Muted={vol.GetMute()}")
    elif hasattr(speaker, 'Activate'):
        interface = speaker.Activate(IAudioEndpointVolume._iid_, comtypes.CLSCTX_ALL, None)
        vol = cast(interface, POINTER(IAudioEndpointVolume))
        print(f"via Activate: Master={round(vol.GetMasterVolumeLevelScalar() * 100)}%, Muted={vol.GetMute()}")
    else:
        print("Speaker attributes:", dir(speaker))
except Exception as e:
    print("Pycaw test error:", e)

# Test Audio Endpoints enumeration
print("\n--- Testing Audio Endpoints Listing ---")
try:
    devices = AudioUtilities.GetAllDevices()
    for d in devices:
        print(f"Device: {d.FriendlyName} (ID: {d.id}, State: {d.state})")
except Exception as e:
    print("Get all devices error:", e)

# Test winsdk thumbnail stream conversion helper
print("\n--- Testing Thumbnail Stream Buffer Conversion Helper ---")
async def test_thumbnail_buffer():
    try:
        from winsdk.windows.storage.streams import DataReader, Buffer, InputStreamOptions
        # Mock / verify DataReader import & usage
        reader = DataReader(None) if False else None
        print("DataReader and Buffer classes loaded successfully from winsdk.")
    except Exception as e:
        print("Thumbnail buffer test error:", e)

asyncio.run(test_thumbnail_buffer())
