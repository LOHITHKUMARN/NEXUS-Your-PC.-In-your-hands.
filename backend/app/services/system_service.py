import time
import socket
import psutil
from typing import List, Optional
from app.models.schemas import SystemTelemetry, DiskInfo, NetworkRate, GpuInfo, BatteryInfo

from app.services.gpu_service import gpu_service

class SystemService:
    def __init__(self):
        self._last_net_time = time.time()
        net_io = psutil.net_io_counters()
        self._last_bytes_recv = net_io.bytes_recv
        self._last_bytes_sent = net_io.bytes_sent
        self._hostname = socket.gethostname()
        self._boot_time = psutil.boot_time()

    def get_gpu_info(self) -> GpuInfo:
        try:
            return gpu_service.get_gpu_info()
        except Exception:
            return GpuInfo(available=False, name="Unavailable", load_percent=0.0)

    def get_network_rates(self) -> NetworkRate:
        now = time.time()
        net_io = psutil.net_io_counters()
        dt = max(now - self._last_net_time, 0.001)
        
        recv_delta = max(0, net_io.bytes_recv - self._last_bytes_recv)
        sent_delta = max(0, net_io.bytes_sent - self._last_bytes_sent)
        
        self._last_net_time = now
        self._last_bytes_recv = net_io.bytes_recv
        self._last_bytes_sent = net_io.bytes_sent
        
        down_kbps = (recv_delta / dt) / 1024.0
        up_kbps = (sent_delta / dt) / 1024.0
        
        return NetworkRate(
            download_kbps=round(down_kbps, 1),
            upload_kbps=round(up_kbps, 1),
            total_download_mb=round(net_io.bytes_recv / (1024 ** 2), 1),
            total_upload_mb=round(net_io.bytes_sent / (1024 ** 2), 1)
        )

    def get_disks(self) -> List[DiskInfo]:
        disks = []
        try:
            partitions = psutil.disk_partitions(all=False)
            for part in partitions:
                if 'cdrom' in part.opts or part.fstype == '':
                    continue
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                    disks.append(DiskInfo(
                        mount=part.mountpoint.replace('\\', ''),
                        total_gb=round(usage.total / (1024 ** 3), 1),
                        used_gb=round(usage.used / (1024 ** 3), 1),
                        free_gb=round(usage.free / (1024 ** 3), 1),
                        percent=usage.percent
                    ))
                except (PermissionError, FileNotFoundError):
                    continue
        except Exception:
            pass
        return disks

    def get_battery_info(self) -> BatteryInfo:
        try:
            battery = psutil.sensors_battery()
            if battery:
                return BatteryInfo(
                    present=True,
                    percent=round(battery.percent, 1),
                    power_plugged=battery.power_plugged,
                    seconds_left=int(battery.secsleft) if battery.secsleft > 0 else None
                )
        except Exception:
            pass
        return BatteryInfo(present=False)

    def get_telemetry(self) -> SystemTelemetry:
        # Non-blocking CPU reading
        cpu_pct = psutil.cpu_percent(interval=None)
        cpu_cores = psutil.cpu_percent(interval=None, percpu=True)
        
        cpu_freq = None
        try:
            freq = psutil.cpu_freq()
            if freq:
                cpu_freq = round(freq.current, 1)
        except Exception:
            pass

        # Memory
        mem = psutil.virtual_memory()
        ram_pct = mem.percent
        ram_used = round(mem.used / (1024 ** 3), 2)
        ram_total = round(mem.total / (1024 ** 3), 2)

        # Uptime
        uptime = int(time.time() - self._boot_time)

        return SystemTelemetry(
            cpu_percent=cpu_pct,
            cpu_cores_percent=cpu_cores,
            cpu_freq_mhz=cpu_freq,
            ram_percent=ram_pct,
            ram_used_gb=ram_used,
            ram_total_gb=ram_total,
            gpu=self.get_gpu_info(),
            disks=self.get_disks(),
            network=self.get_network_rates(),
            battery=self.get_battery_info(),
            hostname=self._hostname,
            uptime_seconds=uptime
        )

    def get_mac_address(self) -> str:
        """Resolves the physical MAC address of the active network adapter."""
        from app.config import get_lan_ip
        active_ip = get_lan_ip()
        try:
            for iface, addrs in psutil.net_if_addrs().items():
                if any(a.address == active_ip for a in addrs):
                    for a in addrs:
                        if a.family == psutil.AF_LINK and a.address:
                            return a.address.replace('-', ':').upper()
        except Exception:
            pass

        try:
            import uuid
            node = uuid.getnode()
            return ':'.join(f'{(node >> i) & 0xff:02X}' for i in range(40, -1, -8))
        except Exception:
            return ""

system_service = SystemService()
