import ctypes
from ctypes import wintypes
import logging
import queue
import threading
from typing import List, Set, Optional

logger = logging.getLogger("pc_control.input")

# Win32 Constants
INPUT_MOUSE = 0
INPUT_KEYBOARD = 1
INPUT_HARDWARE = 2

# Mouse Event Flags
MOUSEEVENTF_MOVE = 0x0001
MOUSEEVENTF_LEFTDOWN = 0x0002
MOUSEEVENTF_LEFTUP = 0x0004
MOUSEEVENTF_RIGHTDOWN = 0x0008
MOUSEEVENTF_RIGHTUP = 0x0010
MOUSEEVENTF_MIDDLEDOWN = 0x0020
MOUSEEVENTF_MIDDLEUP = 0x0040
MOUSEEVENTF_WHEEL = 0x0800
MOUSEEVENTF_HWHEEL = 0x1000
WHEEL_DELTA = 120

# Keyboard Event Flags
KEYEVENTF_EXTENDEDKEY = 0x0001
KEYEVENTF_KEYUP = 0x0002
KEYEVENTF_UNICODE = 0x0004
KEYEVENTF_SCANCODE = 0x0008

# Win32 Ctypes Structures
ULONG_PTR = ctypes.c_ulonglong if ctypes.sizeof(ctypes.c_void_p) == 8 else wintypes.ULONG

class MOUSEINPUT(ctypes.Structure):
    _fields_ = [
        ("dx", wintypes.LONG),
        ("dy", wintypes.LONG),
        ("mouseData", wintypes.DWORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]

class KEYBDINPUT(ctypes.Structure):
    _fields_ = [
        ("wVk", wintypes.WORD),
        ("wScan", wintypes.WORD),
        ("dwFlags", wintypes.DWORD),
        ("time", wintypes.DWORD),
        ("dwExtraInfo", ULONG_PTR),
    ]

class HARDWAREINPUT(ctypes.Structure):
    _fields_ = [
        ("uMsg", wintypes.DWORD),
        ("wParamL", wintypes.WORD),
        ("wParamH", wintypes.WORD),
    ]

class INPUT_UNION(ctypes.Union):
    _fields_ = [
        ("mi", MOUSEINPUT),
        ("ki", KEYBDINPUT),
        ("hi", HARDWAREINPUT),
    ]

class INPUT(ctypes.Structure):
    _fields_ = [
        ("type", wintypes.DWORD),
        ("union", INPUT_UNION),
    ]

# Setup SendInput prototype
try:
    user32 = ctypes.windll.user32
    user32.SendInput.argtypes = [wintypes.UINT, ctypes.POINTER(INPUT), ctypes.c_int]
    user32.SendInput.restype = wintypes.UINT
    user32.OpenInputDesktop.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    user32.OpenInputDesktop.restype = wintypes.HANDLE
    user32.SetThreadDesktop.argtypes = [wintypes.HANDLE]
    user32.SetThreadDesktop.restype = wintypes.BOOL
except Exception as e:
    logger.warning(f"Could not initialize user32.SendInput (likely non-Windows host): {e}")
    user32 = None

# Key mapping table: normalized name -> Virtual Key Code
VK_MAP = {
    # Modifiers
    "ctrl": 0x11,
    "control": 0x11,
    "lctrl": 0xA2,
    "rctrl": 0xA3,
    "shift": 0x10,
    "lshift": 0xA0,
    "rshift": 0xA1,
    "alt": 0x12,
    "menu": 0x12,
    "lalt": 0xA4,
    "ralt": 0xA5,
    "win": 0x5B,
    "cmd": 0x5B,
    "windows": 0x5B,
    # Navigation & Control
    "esc": 0x1B,
    "escape": 0x1B,
    "enter": 0x0D,
    "return": 0x0D,
    "tab": 0x09,
    "space": 0x20,
    "backspace": 0x08,
    "delete": 0x2E,
    "insert": 0x2D,
    "home": 0x24,
    "end": 0x23,
    "pageup": 0x21,
    "pagedown": 0x22,
    "up": 0x26,
    "down": 0x28,
    "left": 0x25,
    "right": 0x27,
    # Functional & Media
    "volmute": 0xAD,
    "voldown": 0xAE,
    "volup": 0xAF,
    "playpause": 0xB3,
    "next": 0xB0,
    "prev": 0xB1,
    "stop": 0xB2,
    "prtscn": 0x2C,
    "printscreen": 0x2C,
}

# Add standard letters A-Z
for ch in range(ord('A'), ord('Z') + 1):
    VK_MAP[chr(ch).lower()] = ch

# Add numbers 0-9
for ch in range(ord('0'), ord('9') + 1):
    VK_MAP[chr(ch)] = ch

# Add F1-F12
for i in range(1, 13):
    VK_MAP[f"f{i}"] = 0x70 + (i - 1)


class InputWorker:
    """
    Dedicated worker thread for SendInput.
    Ensures:
    1. SendInput calls run on a dedicated thread attached to the interactive input desktop.
    2. Input execution never blocks the asyncio event loop.
    3. Low-latency, in-order execution of input events.
    """
    def __init__(self):
        self._queue = queue.Queue(maxsize=3000)
        self._thread = threading.Thread(target=self._run, name="InputWorkerThread", daemon=True)
        self._thread.start()

    def _attach_desktop(self):
        if not user32:
            return
        try:
            hinput = user32.OpenInputDesktop(0, False, 0x01FF)
            if hinput:
                user32.SetThreadDesktop(hinput)
        except Exception:
            pass

    def _run(self):
        self._attach_desktop()
        while True:
            try:
                item = self._queue.get()
                if item is None:
                    break
                func, args, result_event, result_box = item
                try:
                    res = func(*args)
                    if result_box is not None:
                        result_box[0] = res
                except Exception as e:
                    logger.debug(f"Error in InputWorker executing {func}: {e}")
                    if result_box is not None:
                        result_box[0] = False
                finally:
                    if result_event is not None:
                        result_event.set()
                    self._queue.task_done()
            except Exception as e:
                logger.warning(f"Error in InputWorker loop: {e}")

    def submit(self, func, *args, sync: bool = False) -> bool:
        if sync:
            done = threading.Event()
            box = [False]
            try:
                self._queue.put((func, args, done, box), timeout=1.0)
                if done.wait(timeout=2.0):
                    return bool(box[0])
                return False
            except Exception:
                return False
        else:
            try:
                self._queue.put_nowait((func, args, None, None))
                return True
            except queue.Full:
                return False


class InputService:
    """
    Manages low-level Win32 mouse and keyboard injection via user32.SendInput.
    Maintains a safety tracker of held buttons and keys so all can be cleanly released
    if a WebSocket connection unexpectedly drops.
    """
    def __init__(self):
        self._held_mouse_buttons: Set[str] = set()
        self._held_keys: Set[int] = set()
        self._worker = InputWorker()

    def _execute_send_inputs(self, inputs: List[INPUT]) -> bool:
        if not user32 or not inputs:
            return False
        n_inputs = len(inputs)
        arr = (INPUT * n_inputs)(*inputs)
        result = user32.SendInput(n_inputs, arr, ctypes.sizeof(INPUT))
        if result == 0:
            self._worker._attach_desktop()
            result = user32.SendInput(n_inputs, arr, ctypes.sizeof(INPUT))
        return result == n_inputs

    def _send_inputs(self, inputs: List[INPUT], sync: bool = False) -> bool:
        return self._worker.submit(self._execute_send_inputs, inputs, sync=sync)

    def move_relative(self, dx: float, dy: float, sensitivity: float = 1.0) -> bool:
        """Injects relative mouse cursor displacement (fire-and-forget for ultra-low latency)."""
        pixel_dx = int(round(dx * sensitivity))
        pixel_dy = int(round(dy * sensitivity))
        if pixel_dx == 0 and pixel_dy == 0:
            return True

        inp = INPUT(type=INPUT_MOUSE)
        inp.union.mi.dx = pixel_dx
        inp.union.mi.dy = pixel_dy
        inp.union.mi.dwFlags = MOUSEEVENTF_MOVE
        return self._send_inputs([inp], sync=False)

    def mouse_button(self, button: str, action: str, sync: bool = True) -> bool:
        """
        button: 'left', 'right', 'middle'
        action: 'down', 'up', 'tap', 'double'
        """
        btn = button.lower()
        act = action.lower()
        inputs: List[INPUT] = []

        down_flag = 0
        up_flag = 0
        if btn == "left":
            down_flag = MOUSEEVENTF_LEFTDOWN
            up_flag = MOUSEEVENTF_LEFTUP
        elif btn == "right":
            down_flag = MOUSEEVENTF_RIGHTDOWN
            up_flag = MOUSEEVENTF_RIGHTUP
        elif btn == "middle":
            down_flag = MOUSEEVENTF_MIDDLEDOWN
            up_flag = MOUSEEVENTF_MIDDLEUP
        else:
            logger.warning(f"Unknown mouse button: {button}")
            return False

        if act == "down":
            inp = INPUT(type=INPUT_MOUSE)
            inp.union.mi.dwFlags = down_flag
            inputs.append(inp)
            self._held_mouse_buttons.add(btn)
        elif act == "up":
            inp = INPUT(type=INPUT_MOUSE)
            inp.union.mi.dwFlags = up_flag
            inputs.append(inp)
            self._held_mouse_buttons.discard(btn)
        elif act == "tap":
            inp_down = INPUT(type=INPUT_MOUSE)
            inp_down.union.mi.dwFlags = down_flag
            inp_up = INPUT(type=INPUT_MOUSE)
            inp_up.union.mi.dwFlags = up_flag
            inputs.extend([inp_down, inp_up])
            self._held_mouse_buttons.discard(btn)
        elif act == "double":
            for _ in range(2):
                inp_down = INPUT(type=INPUT_MOUSE)
                inp_down.union.mi.dwFlags = down_flag
                inp_up = INPUT(type=INPUT_MOUSE)
                inp_up.union.mi.dwFlags = up_flag
                inputs.extend([inp_down, inp_up])
            self._held_mouse_buttons.discard(btn)
        else:
            logger.warning(f"Unknown mouse action: {action}")
            return False

        return self._send_inputs(inputs, sync=sync)

    def scroll(self, dy: float, dx: float = 0.0, natural: bool = True, sync: bool = False) -> bool:
        """
        dy: vertical scroll units.
        dx: horizontal scroll units (optional).
        natural: if True, swipe down scrolls content down (inverting Windows wheel sign).
        """
        inputs: List[INPUT] = []
        multiplier = -1 if natural else 1

        if dy != 0:
            scroll_amt = int(round(dy * (WHEEL_DELTA / 4) * multiplier))
            if scroll_amt != 0:
                inp = INPUT(type=INPUT_MOUSE)
                inp.union.mi.dwFlags = MOUSEEVENTF_WHEEL
                inp.union.mi.mouseData = wintypes.DWORD(scroll_amt & 0xFFFFFFFF)
                inputs.append(inp)

        if dx != 0:
            h_scroll_amt = int(round(dx * (WHEEL_DELTA / 4) * multiplier))
            if h_scroll_amt != 0:
                inp = INPUT(type=INPUT_MOUSE)
                inp.union.mi.dwFlags = MOUSEEVENTF_HWHEEL
                inp.union.mi.mouseData = wintypes.DWORD(h_scroll_amt & 0xFFFFFFFF)
                inputs.append(inp)

        if inputs:
            return self._send_inputs(inputs, sync=sync)
        return True

    def send_key(self, code: str, action: str = "tap", sync: bool = True) -> bool:
        """Single key press by name/code."""
        key_lower = code.lower()
        vk = VK_MAP.get(key_lower)
        if not vk:
            logger.warning(f"Unknown virtual key code: {code}")
            return False

        act = action.lower()
        inputs: List[INPUT] = []

        if act == "down":
            inp = INPUT(type=INPUT_KEYBOARD)
            inp.union.ki.wVk = vk
            inp.union.ki.dwFlags = 0
            inputs.append(inp)
            self._held_keys.add(vk)
        elif act == "up":
            inp = INPUT(type=INPUT_KEYBOARD)
            inp.union.ki.wVk = vk
            inp.union.ki.dwFlags = KEYEVENTF_KEYUP
            inputs.append(inp)
            self._held_keys.discard(vk)
        elif act == "tap":
            inp_down = INPUT(type=INPUT_KEYBOARD)
            inp_down.union.ki.wVk = vk
            inp_down.union.ki.dwFlags = 0
            inp_up = INPUT(type=INPUT_KEYBOARD)
            inp_up.union.ki.wVk = vk
            inp_up.union.ki.dwFlags = KEYEVENTF_KEYUP
            inputs.extend([inp_down, inp_up])
            self._held_keys.discard(vk)
        else:
            return False

        return self._send_inputs(inputs, sync=sync)

    def send_key_combo(self, keys: List[str], sync: bool = True) -> bool:
        """
        Presses keys down in order, then releases them in reverse order.
        e.g. ['ctrl', 'c'] -> ctrl_down, c_down, c_up, ctrl_up.
        """
        vk_list = []
        for k in keys:
            vk = VK_MAP.get(k.lower())
            if vk:
                vk_list.append(vk)
            else:
                logger.warning(f"Key in combo not found: {k}")

        if not vk_list:
            return False

        inputs: List[INPUT] = []
        # Press in order
        for vk in vk_list:
            inp = INPUT(type=INPUT_KEYBOARD)
            inp.union.ki.wVk = vk
            inp.union.ki.dwFlags = 0
            inputs.append(inp)

        # Release in reverse order
        for vk in reversed(vk_list):
            inp = INPUT(type=INPUT_KEYBOARD)
            inp.union.ki.wVk = vk
            inp.union.ki.dwFlags = KEYEVENTF_KEYUP
            inputs.append(inp)

        return self._send_inputs(inputs, sync=sync)

    def send_text(self, text: str, sync: bool = True) -> bool:
        """
        Injects unicode text using KEYEVENTF_UNICODE.
        Accurately handles surrogate pairs for non-BMP characters / emojis (e.g. 🚀).
        Windows SendInput requires 16-bit code units (UTF-16LE).
        """
        if not text:
            return True

        # Encode to UTF-16LE to get exact 16-bit code units (surrogate pairs where applicable)
        utf16_bytes = text.encode("utf-16-le")
        inputs: List[INPUT] = []

        # Read 2 bytes at a time
        for i in range(0, len(utf16_bytes), 2):
            code_unit = int.from_bytes(utf16_bytes[i:i+2], byteorder="little")

            # Key Down
            inp_down = INPUT(type=INPUT_KEYBOARD)
            inp_down.union.ki.wVk = 0
            inp_down.union.ki.wScan = code_unit
            inp_down.union.ki.dwFlags = KEYEVENTF_UNICODE
            inputs.append(inp_down)

            # Key Up
            inp_up = INPUT(type=INPUT_KEYBOARD)
            inp_up.union.ki.wVk = 0
            inp_up.union.ki.wScan = code_unit
            inp_up.union.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP
            inputs.append(inp_up)

        return self._send_inputs(inputs, sync=sync)

    def release_all(self):
        """
        SAFETY NET: Releases all currently held mouse buttons and modifier keys.
        Crucial when a WebSocket disconnects mid-drag or mid-hotkey.
        """
        inputs: List[INPUT] = []

        # Release all mouse buttons
        for btn in list(self._held_mouse_buttons):
            up_flag = 0
            if btn == "left":
                up_flag = MOUSEEVENTF_LEFTUP
            elif btn == "right":
                up_flag = MOUSEEVENTF_RIGHTUP
            elif btn == "middle":
                up_flag = MOUSEEVENTF_MIDDLEUP

            if up_flag:
                inp = INPUT(type=INPUT_MOUSE)
                inp.union.mi.dwFlags = up_flag
                inputs.append(inp)

        self._held_mouse_buttons.clear()

        # Release all keyboard keys in reverse
        for vk in list(self._held_keys):
            inp = INPUT(type=INPUT_KEYBOARD)
            inp.union.ki.wVk = vk
            inp.union.ki.dwFlags = KEYEVENTF_KEYUP
            inputs.append(inp)

        self._held_keys.clear()

        if inputs:
            logger.info(f"InputService: Safety net triggered — released {len(inputs)} held buttons/keys.")
            self._send_inputs(inputs, sync=True)


input_service = InputService()
