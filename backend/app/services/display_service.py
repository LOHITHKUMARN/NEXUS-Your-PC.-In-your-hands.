import logging
from typing import Optional
import screen_brightness_control as sbc
from app.models.schemas import DisplayStatus

logger = logging.getLogger("pc_control.display")

class DisplayService:
    def get_status(self) -> DisplayStatus:
        brightness_val = 100
        count = 1
        
        # 1. Fast WMI query (avoids EDID parse warnings on laptop internal displays)
        try:
            import wmi
            w = wmi.WMI(namespace="root\\wmi")
            monitors = w.WmiMonitorBrightness()
            if monitors:
                brightness_val = int(monitors[0].CurrentBrightness)
                count = len(monitors)
                return DisplayStatus(brightness=brightness_val, display_count=count)
        except Exception:
            pass

        # 2. Fallback to screen_brightness_control
        try:
            b_list = sbc.get_brightness()
            if isinstance(b_list, list) and len(b_list) > 0:
                brightness_val = int(b_list[0])
                count = len(b_list)
            elif isinstance(b_list, (int, float)):
                brightness_val = int(b_list)
        except Exception as e:
            logger.debug(f"Could not read screen brightness: {e}")

        return DisplayStatus(
            brightness=brightness_val,
            display_count=count
        )

    def set_brightness(self, value: int) -> bool:
        try:
            val = max(0, min(100, value))
            sbc.set_brightness(val)
            return True
        except Exception as e:
            logger.error(f"Error setting brightness to {value}: {e}")
            return False

display_service = DisplayService()
