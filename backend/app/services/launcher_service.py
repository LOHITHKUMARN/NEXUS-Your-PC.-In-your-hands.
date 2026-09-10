import os
import subprocess
import logging
import psutil
from typing import List, Optional
from app.config import settings, AppLauncherConfig
from app.models.schemas import AppItem, RunningTask

logger = logging.getLogger("pc_control.launcher")

class LauncherService:
    def __init__(self):
        self._apps: List[AppLauncherConfig] = list(settings.DEFAULT_APPS)

    def get_apps(self) -> List[AppItem]:
        # Check running processes to mark `is_running`
        running_names = set()
        for p in psutil.process_iter(['name']):
            try:
                name = p.info['name']
                if name:
                    running_names.add(name.lower())
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue

        result = []
        for a in self._apps:
            # Check if app process name matches
            cmd_base = os.path.basename(a.command).lower().replace('.exe', '')
            is_running = any(cmd_base in r_name for r_name in running_names)
            result.append(AppItem(
                id=a.id,
                name=a.name,
                command=a.command,
                icon=a.icon,
                description=a.description,
                is_running=is_running
            ))
        return result

    def launch_app(self, app_id: str) -> bool:
        target = next((a for a in self._apps if a.id == app_id), None)
        if not target:
            logger.warning(f"App ID {app_id} is not in allowlisted apps.")
            return False

        try:
            # Use explorer or cmd to launch GUI app safely detached
            os.startfile(target.command)
            return True
        except Exception as e:
            logger.info(f"os.startfile failed for {target.command}, trying subprocess: {e}")
            try:
                subprocess.Popen(
                    target.command,
                    shell=True,
                    creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS
                )
                return True
            except Exception as e2:
                logger.error(f"Failed to launch app {app_id}: {e2}")
                return False

    def get_top_tasks(self, limit: int = 15) -> List[RunningTask]:
        tasks: List[RunningTask] = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
            try:
                info = proc.info
                mem_mb = (info['memory_info'].rss / (1024 * 1024)) if info['memory_info'] else 0
                tasks.append(RunningTask(
                    pid=info['pid'],
                    name=info['name'] or 'Unknown',
                    cpu_percent=info['cpu_percent'] or 0.0,
                    memory_mb=round(mem_mb, 1)
                ))
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        # Sort by memory usage descending
        tasks.sort(key=lambda x: x.memory_mb, reverse=True)
        return tasks[:limit]

    def kill_task(self, pid: int, client_ip: str = "127.0.0.1") -> bool:
        """Terminates a running process by PID and records audit event."""
        try:
            p = psutil.Process(pid)
            name = p.name()
            p.terminate()
            logger.info(f"Terminated process {name} (PID {pid}) requested by {client_ip}")
            try:
                from app.services.audit_service import audit_service
                audit_service.record_event("process_killed", client_ip, {"pid": pid, "name": name})
            except Exception:
                pass
            return True
        except (psutil.NoSuchProcess, psutil.AccessDenied) as e:
            logger.warning(f"Could not kill process PID {pid}: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error killing process PID {pid}: {e}")
            return False

launcher_service = LauncherService()
