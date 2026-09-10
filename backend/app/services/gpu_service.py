import time
import logging
import warnings
import ctypes
from ctypes import c_int, c_void_p, Structure, byref
from typing import Optional, List, Tuple
from app.models.schemas import GpuInfo

warnings.filterwarnings("ignore", category=FutureWarning, module="pynvml")
logger = logging.getLogger(__name__)

class GpuService:
    def __init__(self):
        self._gpu_name: str = "GPU"
        self._vram_total_mb: float = 0.0
        self._nvml_initialized: bool = False
        self._adl_initialized: bool = False
        self._adl_handle = None
        self._malloc_cb = None
        
        # PDH (Performance Data Helper) state
        self._pdh_query = None
        self._pdh_load_handles: List = []
        self._pdh_vram_handles: List = []
        self._last_pdh_refresh: float = 0.0
        
        # Initialize GPU hardware detection
        self._init_hardware_info()
        self._init_nvml()
        if not self._nvml_initialized:
            self._init_amd_adl()
        self._init_pdh()

    def _init_hardware_info(self):
        """Discovers GPU Name and total VRAM from WMI Win32_VideoController."""
        try:
            import wmi
            w = wmi.WMI()
            controllers = w.Win32_VideoController()
            
            chosen_controller = None
            # Prioritize dedicated GPUs (e.g. RX, RTX, GTX, Radeon, GeForce, Arc)
            for c in controllers:
                name = c.Name or ""
                # Skip basic/virtual adapters
                if "Virtual" in name or "Basic Display" in name:
                    continue
                # If it's a discrete GPU brand and not integrated
                if any(tag in name for tag in ["Radeon(TM) RX", "GeForce", "RTX", "GTX", "Arc(TM)"]):
                    chosen_controller = c
                    break
                if "Radeon" in name or "NVIDIA" in name or "Intel" in name:
                    if chosen_controller is None:
                        chosen_controller = c

            if not chosen_controller and controllers:
                chosen_controller = controllers[0]

            if chosen_controller:
                self._gpu_name = chosen_controller.Name or "GPU"
                raw_ram = chosen_controller.AdapterRAM or 0
                if raw_ram < 0:
                    raw_ram += (1 << 32)
                self._vram_total_mb = round(raw_ram / (1024 ** 2), 1)
        except Exception as e:
            logger.warning(f"Error querying WMI GPU hardware: {e}")
            self._gpu_name = "GPU"

    def _init_nvml(self):
        """Initializes NVIDIA NVML if NVIDIA GPU is present."""
        try:
            import pynvml
            pynvml.nvmlInit()
            if pynvml.nvmlDeviceGetCount() > 0:
                self._nvml_initialized = True
                logger.info("NVIDIA NVML initialized successfully.")
        except Exception:
            self._nvml_initialized = False

    def _init_amd_adl(self):
        """Initializes AMD Display Library (ADL) for AMD GPU temperature & telemetry."""
        try:
            adl = ctypes.cdll.LoadLibrary("atiadlxx.dll")
            MALLOC_FUNC = ctypes.WINFUNCTYPE(c_void_p, c_int)
            def _malloc(size):
                return ctypes.windll.msvcrt.malloc(size)
            self._malloc_cb = MALLOC_FUNC(_malloc)
            
            if adl.ADL_Main_Control_Create(self._malloc_cb, 1) == 0:
                self._adl_handle = adl
                self._adl_initialized = True
                logger.info("AMD ADL initialized successfully.")
        except Exception as e:
            self._adl_initialized = False
            self._adl_handle = None

    def _init_pdh(self):
        """Initializes Windows PDH counters for GPU Engine utilization and VRAM."""
        try:
            import win32pdh
            if self._pdh_query is not None:
                try:
                    win32pdh.CloseQuery(self._pdh_query)
                except Exception:
                    pass
            
            self._pdh_query = win32pdh.OpenQuery()
            self._pdh_load_handles = []
            self._pdh_vram_handles = []

            # 1. GPU Engine utilization counters
            try:
                _, instances = win32pdh.EnumObjectItems(None, None, "GPU Engine", -1)
                for inst in instances:
                    # Focus on 3D, Compute, Graphics, and VR engines for load
                    if any(eng in inst for eng in ["engtype_3D", "engtype_Compute", "engtype_Graphics", "engtype_VR"]):
                        try:
                            path = win32pdh.MakeCounterPath((None, "GPU Engine", inst, None, -1, "Utilization Percentage"))
                            h = win32pdh.AddCounter(self._pdh_query, path)
                            self._pdh_load_handles.append(h)
                        except Exception:
                            pass
            except Exception:
                pass

            # 2. GPU Dedicated Memory counters
            try:
                _, mem_instances = win32pdh.EnumObjectItems(None, None, "GPU Adapter Memory", -1)
                for inst in mem_instances:
                    try:
                        path = win32pdh.MakeCounterPath((None, "GPU Adapter Memory", inst, None, -1, "Dedicated Usage"))
                        h = win32pdh.AddCounter(self._pdh_query, path)
                        self._pdh_vram_handles.append(h)
                    except Exception:
                        pass
            except Exception:
                pass

            if self._pdh_query:
                win32pdh.CollectQueryData(self._pdh_query)
            
            self._last_pdh_refresh = time.time()
        except Exception as e:
            logger.warning(f"Error initializing Windows PDH GPU counters: {e}")
            self._pdh_query = None

    def _get_amd_temperature(self) -> Optional[float]:
        """Queries GPU temperature via AMD ADL."""
        if not self._adl_initialized or not self._adl_handle:
            return None
        
        try:
            temp_val = c_int(0)
            # Try OverdriveN (RX 5000 / 6000 / 7000 series)
            if hasattr(self._adl_handle, "ADL2_OverdriveN_Temperature_Get"):
                for adapter_idx in range(4):
                    # 1 = EDGE temperature sensor
                    if self._adl_handle.ADL2_OverdriveN_Temperature_Get(None, adapter_idx, 1, byref(temp_val)) == 0:
                        if temp_val.value > 0:
                            return round(temp_val.value / 1000.0, 1)
            
            # Try Overdrive6
            if hasattr(self._adl_handle, "ADL_Overdrive6_Temperature_Get"):
                for adapter_idx in range(4):
                    if self._adl_handle.ADL_Overdrive6_Temperature_Get(adapter_idx, byref(temp_val)) == 0:
                        if temp_val.value > 0:
                            return round(temp_val.value / 1000.0, 1)
        except Exception:
            pass
        return None

    def get_gpu_info(self) -> GpuInfo:
        """Returns standard GpuInfo schema for any GPU (NVIDIA, AMD, Intel)."""
        # 1. NVIDIA NVML path
        if self._nvml_initialized:
            try:
                import pynvml
                count = pynvml.nvmlDeviceGetCount()
                if count > 0:
                    handle = pynvml.nvmlDeviceGetHandleByIndex(0)
                    name_bytes = pynvml.nvmlDeviceGetName(handle)
                    name = name_bytes.decode("utf-8") if isinstance(name_bytes, bytes) else str(name_bytes)
                    util = pynvml.nvmlDeviceGetUtilizationRates(handle)
                    mem = pynvml.nvmlDeviceGetMemoryInfo(handle)
                    temp = pynvml.nvmlDeviceGetTemperature(handle, pynvml.NVML_TEMPERATURE_GPU)
                    return GpuInfo(
                        available=True,
                        name=name,
                        load_percent=round(float(util.gpu), 1),
                        temperature_c=round(float(temp), 1),
                        vram_used_mb=round(float(mem.used / (1024 ** 2)), 1),
                        vram_total_mb=round(float(mem.total / (1024 ** 2)), 1)
                    )
            except Exception:
                pass

        # 2. AMD / Intel / Generic Windows GPU path via PDH & ADL
        now = time.time()
        if (now - self._last_pdh_refresh) > 30.0 or not self._pdh_query:
            self._init_pdh()

        load_percent = 0.0
        vram_used_mb = 0.0

        if self._pdh_query:
            try:
                import win32pdh
                win32pdh.CollectQueryData(self._pdh_query)
                
                # Aggregate engine load
                for h in self._pdh_load_handles:
                    try:
                        _, val = win32pdh.GetFormattedCounterValue(h, win32pdh.PDH_FMT_DOUBLE)
                        load_percent += val
                    except Exception:
                        pass
                
                # Aggregate dedicated VRAM usage
                for h in self._pdh_vram_handles:
                    try:
                        _, val = win32pdh.GetFormattedCounterValue(h, win32pdh.PDH_FMT_LARGE)
                        vram_used_mb += (val / (1024 ** 2))
                    except Exception:
                        pass
            except Exception:
                pass

        load_percent = min(100.0, round(load_percent, 1))
        vram_used_mb = round(vram_used_mb, 1)
        temp_c = self._get_amd_temperature()

        return GpuInfo(
            available=True,
            name=self._gpu_name,
            load_percent=load_percent,
            temperature_c=temp_c,
            vram_used_mb=vram_used_mb,
            vram_total_mb=self._vram_total_mb
        )

gpu_service = GpuService()
