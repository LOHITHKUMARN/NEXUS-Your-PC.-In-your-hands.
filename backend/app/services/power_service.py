import ctypes
import os
import subprocess
import logging
from typing import Tuple

logger = logging.getLogger("pc_control.power")

class PowerService:
    def lock_workstation(self) -> Tuple[bool, str]:
        try:
            res = ctypes.windll.user32.LockWorkStation()
            if res != 0:
                return True, "Workstation locked successfully"
            return False, "Failed to lock workstation"
        except Exception as e:
            logger.error(f"Error locking workstation: {e}")
            return False, str(e)

    def sleep_system(self) -> Tuple[bool, str]:
        try:
            # SetSuspendState(bHibernate=False, bForce=False, bWakeupEventsDisabled=False)
            res = ctypes.windll.powrprof.SetSuspendState(0, 0, 0)
            if res != 0:
                return True, "System entering sleep mode"
            # Fallback to shell command if powrprof returned 0
            subprocess.run(["rundll32.exe", "powrprof.dll,SetSuspendState", "0,0,0"], creationflags=subprocess.CREATE_NO_WINDOW)
            return True, "System entering sleep mode"
        except Exception as e:
            logger.error(f"Error putting system to sleep: {e}")
            return False, str(e)

    def turn_off_display(self) -> Tuple[bool, str]:
        try:
            # SC_MONITORPOWER = 0xF170, 2 = Power off
            HWND_BROADCAST = 0xFFFF
            WM_SYSCOMMAND = 0x0112
            SC_MONITORPOWER = 0xF170
            ctypes.windll.user32.PostMessageW(HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, 2)
            return True, "Display turned off (Screen Off)"
        except Exception as e:
            logger.error(f"Error turning off display: {e}")
            return False, str(e)

    def turn_on_display(self) -> Tuple[bool, str]:
        try:
            # Wake display by sending monitor power on (-1) and simulating subtle input event
            HWND_BROADCAST = 0xFFFF
            WM_SYSCOMMAND = 0x0112
            SC_MONITORPOWER = 0xF170
            
            # 1. Post message to wake monitor
            ctypes.windll.user32.PostMessageW(HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, -1)
            
            # 2. Simulate slight mouse jitter to wake display subsystem from DPMS
            ctypes.windll.user32.mouse_event(0x0001, 1, 0, 0, 0)
            ctypes.windll.user32.mouse_event(0x0001, -1, 0, 0, 0)
            
            # 3. Notify Windows that display & system are required
            ctypes.windll.kernel32.SetThreadExecutionState(0x00000002 | 0x00000001)
            
            return True, "Display turned on (Screen On)"
        except Exception as e:
            logger.error(f"Error turning on display: {e}")
            return False, str(e)

    def restart_pc(self, delay_seconds: int = 0, force: bool = False) -> Tuple[bool, str]:
        try:
            cmd = ["shutdown", "/r", f"/t", str(max(0, delay_seconds))]
            if force:
                cmd.append("/f")
            subprocess.run(cmd, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
            return True, f"System restarting in {delay_seconds} seconds"
        except Exception as e:
            logger.error(f"Error restarting PC: {e}")
            return False, str(e)

    def shutdown_pc(self, delay_seconds: int = 0, force: bool = False) -> Tuple[bool, str]:
        try:
            cmd = ["shutdown", "/s", f"/t", str(max(0, delay_seconds))]
            if force:
                cmd.append("/f")
            subprocess.run(cmd, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
            return True, f"System shutting down in {delay_seconds} seconds"
        except Exception as e:
            logger.error(f"Error shutting down PC: {e}")
            return False, str(e)

    def abort_shutdown(self) -> Tuple[bool, str]:
        try:
            subprocess.run(["shutdown", "/a"], check=True, creationflags=subprocess.CREATE_NO_WINDOW)
            return True, "Scheduled shutdown aborted"
        except Exception as e:
            logger.error(f"Error aborting shutdown: {e}")
            return False, str(e)

power_service = PowerService()
