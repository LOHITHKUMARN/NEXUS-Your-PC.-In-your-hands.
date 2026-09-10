import os
import sys
import webbrowser
import logging
import threading
import winreg
from PIL import Image, ImageDraw
import pystray
from app.config import settings, get_lan_ip

logger = logging.getLogger("pc_control.tray")

def create_tray_icon_image():
    """Loads the app logo icon for the system tray, falling back to a generated icon."""
    assets_dir = os.path.join(os.path.dirname(__file__), "assets")
    tray_png = os.path.join(assets_dir, "tray_icon.png")
    if os.path.exists(tray_png):
        try:
            return Image.open(tray_png).convert("RGBA").resize((64, 64), Image.Resampling.LANCZOS)
        except Exception as e:
            logger.warning(f"Could not load tray icon asset: {e}")

    image = Image.new("RGBA", (64, 64), color=(0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Outer dark circle
    draw.ellipse([4, 4, 60, 60], fill=(18, 24, 38, 255), outline=(0, 240, 255, 255), width=3)
    
    # Inner glowing cyan core
    draw.ellipse([18, 18, 46, 46], fill=(0, 240, 255, 255))
    
    # Inner dot
    draw.ellipse([26, 26, 38, 38], fill=(255, 255, 255, 255))
    return image

def set_autostart_registry(enable: bool) -> bool:
    key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
    app_name = "PCControlCenter"
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_SET_VALUE)
        if enable:
            exe_path = sys.executable if getattr(sys, 'frozen', False) else os.path.abspath(sys.argv[0])
            winreg.SetValueEx(key, app_name, 0, winreg.REG_SZ, f'"{exe_path}"')
        else:
            try:
                winreg.DeleteValue(key, app_name)
            except FileNotFoundError:
                pass
        winreg.CloseKey(key)
        return True
    except Exception as e:
        logger.error(f"Error setting autostart registry: {e}")
        return False

def is_autostart_enabled() -> bool:
    key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
    app_name = "PCControlCenter"
    try:
        key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_READ)
        winreg.QueryValueEx(key, app_name)
        winreg.CloseKey(key)
        return True
    except Exception:
        return False

class SystemTrayApp:
    def __init__(self, on_exit_callback=None):
        self.on_exit = on_exit_callback
        self.icon = None

    def copy_lan_ip(self, icon, item):
        try:
            lan_ip = get_lan_ip()
            import subprocess
            subprocess.run(
                ["powershell", "-NoProfile", "-Command", f"Set-Clipboard -Value '{lan_ip}'"],
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            if self.icon:
                self.icon.notify(f"PC IP copied to clipboard: {lan_ip}", "PC Control Center")
        except Exception as e:
            logger.error(f"Failed to copy LAN IP: {e}")

    def copy_api_key(self, icon, item):
        try:
            import subprocess
            subprocess.run(
                ["powershell", "-NoProfile", "-Command", f"Set-Clipboard -Value '{settings.API_KEY}'"],
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            if self.icon:
                self.icon.notify(f"API Key copied: {settings.API_KEY}", "PC Control Center")
        except Exception as e:
            logger.error(f"Failed to copy API key: {e}")

    def copy_pairing_uri(self, icon, item):
        try:
            uri = settings.get_pairing_uri()
            import subprocess
            subprocess.run(
                ["powershell", "-NoProfile", "-Command", f"Set-Clipboard -Value '{uri}'"],
                creationflags=subprocess.CREATE_NO_WINDOW
            )
            if self.icon:
                self.icon.notify("Pairing Code copied! Paste into mobile app to pair instantly.", "PC Control Center")
        except Exception as e:
            logger.error(f"Failed to copy pairing URI: {e}")

    def rotate_key_action(self, icon, item):
        new_key = settings.rotate_api_key()
        if self.icon:
            self.icon.notify(f"New API Key generated: {new_key}", "PC Control Center")

    def open_api_docs(self, icon, item):
        webbrowser.open(f"http://127.0.0.1:{settings.PORT}/docs")

    def toggle_autostart(self, icon, item):
        curr = is_autostart_enabled()
        set_autostart_registry(not curr)

    def view_recent_activity(self, icon, item):
        try:
            from app.services.audit_service import audit_service
            events = audit_service.get_events(limit=5)
            if not events:
                msg = "No recent connection or security events."
            else:
                lines = []
                for ev in events:
                    ts = ev.get("timestamp", "")[11:19]
                    lines.append(f"[{ts}] {ev.get('event')} ({ev.get('client_ip')})")
                msg = "\n".join(lines)
            if self.icon:
                self.icon.notify(msg, "Recent Activity (Last 5)")
        except Exception as e:
            logger.error(f"Failed to show recent activity: {e}")

    def exit_app(self, icon, item):
        if self.icon:
            self.icon.stop()
        if self.on_exit:
            self.on_exit()

    def run(self):
        lan_ip = get_lan_ip()
        menu = pystray.Menu(
            pystray.MenuItem("🚀 PC Control Center", None, enabled=False),
            pystray.MenuItem(f"IP: {lan_ip}:{settings.PORT}", self.copy_lan_ip),
            pystray.MenuItem(f"API Key: {settings.API_KEY}", self.copy_api_key),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("View Recent Activity", self.view_recent_activity),
            pystray.MenuItem("Copy Fast-Pairing Code (URI)", self.copy_pairing_uri),
            pystray.MenuItem("Copy PC IP Address", self.copy_lan_ip),
            pystray.MenuItem("Copy API Key", self.copy_api_key),
            pystray.MenuItem("Rotate API Key", self.rotate_key_action),
            pystray.MenuItem("Open API Docs in Browser", self.open_api_docs),
            pystray.MenuItem("Start with Windows", self.toggle_autostart, checked=lambda item: is_autostart_enabled()),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Exit Server", self.exit_app)
        )
        self.icon = pystray.Icon(
            "pc_control_center",
            create_tray_icon_image(),
            f"PC Control Center ({lan_ip}:{settings.PORT})",
            menu=menu
        )
        self.icon.run()

