import logging
from typing import List, Optional, Tuple
from pycaw.pycaw import AudioUtilities
from app.models.schemas import AudioStatus, AudioDevice
from app.core.policy_config import set_default_audio_device

logger = logging.getLogger("pc_control.audio")

class AudioService:
    def _get_master_volume_interface(self):
        try:
            speaker = AudioUtilities.GetSpeakers()
            if speaker is None:
                return None
            if hasattr(speaker, 'EndpointVolume'):
                return speaker.EndpointVolume
            elif hasattr(speaker, 'endpoint_volume'):
                return speaker.endpoint_volume
        except Exception as e:
            logger.error(f"Failed to get speaker volume interface: {e}")
        return None

    def get_status(self) -> AudioStatus:
        vol_interface = self._get_master_volume_interface()
        master_vol = 0
        is_muted = False
        
        if vol_interface:
            try:
                scalar = vol_interface.GetMasterVolumeLevelScalar()
                master_vol = int(round(scalar * 100))
                is_muted = bool(vol_interface.GetMute())
            except Exception as e:
                logger.error(f"Error reading volume/mute: {e}")

        devices, active_device = self.get_devices()
        return AudioStatus(
            master_volume=master_vol,
            is_muted=is_muted,
            devices=devices,
            active_device_name=active_device
        )

    def set_volume(self, volume_percent: int) -> bool:
        vol_interface = self._get_master_volume_interface()
        if not vol_interface:
            return False
        try:
            val = max(0, min(100, volume_percent)) / 100.0
            vol_interface.SetMasterVolumeLevelScalar(val, None)
            return True
        except Exception as e:
            logger.error(f"Error setting volume: {e}")
            return False

    def step_volume(self, delta: int) -> int:
        vol_interface = self._get_master_volume_interface()
        if not vol_interface:
            return 0
        try:
            curr = vol_interface.GetMasterVolumeLevelScalar()
            new_val = max(0.0, min(1.0, curr + (delta / 100.0)))
            vol_interface.SetMasterVolumeLevelScalar(new_val, None)
            return int(round(new_val * 100))
        except Exception as e:
            logger.error(f"Error stepping volume: {e}")
            return 0

    def set_mute(self, mute: bool) -> bool:
        vol_interface = self._get_master_volume_interface()
        if not vol_interface:
            return False
        try:
            vol_interface.SetMute(1 if mute else 0, None)
            return True
        except Exception as e:
            logger.error(f"Error setting mute: {e}")
            return False

    def toggle_mute(self) -> bool:
        vol_interface = self._get_master_volume_interface()
        if not vol_interface:
            return False
        try:
            current = bool(vol_interface.GetMute())
            vol_interface.SetMute(0 if current else 1, None)
            return not current
        except Exception as e:
            logger.error(f"Error toggling mute: {e}")
            return False

    def get_devices(self) -> Tuple[List[AudioDevice], Optional[str]]:
        devices_list: List[AudioDevice] = []
        active_name: Optional[str] = None
        try:
            # Active speaker ID
            curr_speaker = AudioUtilities.GetSpeakers()
            curr_id = getattr(curr_speaker, 'id', None)
            if curr_speaker:
                active_name = getattr(curr_speaker, 'FriendlyName', None) or getattr(curr_speaker, 'friendly_name', None)

            all_devices = AudioUtilities.GetAllDevices()
            for d in all_devices:
                # Filter for active audio output devices
                state_str = str(getattr(d, 'state', 'Active'))
                dev_id = getattr(d, 'id', '')
                name = getattr(d, 'FriendlyName', '') or getattr(d, 'friendly_name', 'Unknown Device')
                
                # Check if it's a playback endpoint (dataflow == 0 or state == Active)
                is_active = "Active" in state_str
                is_def = (dev_id == curr_id)
                
                if is_active and name:
                    devices_list.append(AudioDevice(
                        id=dev_id,
                        name=name,
                        is_default=is_def,
                        state="Active"
                    ))
        except Exception as e:
            logger.warning(f"Failed to list audio devices: {e}")
        return devices_list, active_name

    def switch_device(self, device_id: str) -> bool:
        return set_default_audio_device(device_id)

audio_service = AudioService()
