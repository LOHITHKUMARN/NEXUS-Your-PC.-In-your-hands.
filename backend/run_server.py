import sys
import io
import threading
import uvicorn
from app.config import settings, get_lan_ip
from app.tray import SystemTrayApp

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

def disable_quick_edit():
    """Disables Windows console QuickEdit mode so mouse clicks inside the terminal do not freeze the server."""
    if sys.platform == "win32":
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32
            hStdin = kernel32.GetStdHandle(-10)  # STD_INPUT_HANDLE = -10
            mode = ctypes.c_ulong()
            if kernel32.GetConsoleMode(hStdin, ctypes.byref(mode)):
                ENABLE_QUICK_EDIT_MODE = 0x0040
                ENABLE_EXTENDED_FLAGS = 0x0080
                new_mode = (mode.value & ~ENABLE_QUICK_EDIT_MODE) | ENABLE_EXTENDED_FLAGS
                kernel32.SetConsoleMode(hStdin, new_mode)
        except Exception:
            pass

def start_api_server(server_instance):
    server_instance.run()

def main():
    disable_quick_edit()
    use_tray = "--no-tray" not in sys.argv
    lan_ip = get_lan_ip()
    
    config = uvicorn.Config(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        log_level="info",
        reload=False
    )
    server = uvicorn.Server(config)
    
    print(f"==================================================")
    print(f"🚀 PC Control Center Host Server Active")
    print(f"   ► Local PC URL:  http://127.0.0.1:{settings.PORT}")
    print(f"   ► Phone / LAN:   http://{lan_ip}:{settings.PORT}")
    print(f"   ► API Key:       {settings.API_KEY}")
    print(f"   ► Swagger Docs:  http://127.0.0.1:{settings.PORT}/docs")
    print(f"--------------------------------------------------")
    print(f"💡 On your Phone/Tablet App:")
    print(f"   1. Enter Host IP: {lan_ip}")
    print(f"   2. Enter API Key: {settings.API_KEY}")
    print(f"   (Or tap 'Auto-Discover PC' on your mobile app)")
    print(f"==================================================")

    if use_tray:
        # Start uvicorn in background thread
        server_thread = threading.Thread(target=start_api_server, args=(server,), daemon=True)
        server_thread.start()
        
        # Run system tray icon on main thread
        tray = SystemTrayApp(on_exit_callback=lambda: setattr(server, 'should_exit', True))
        try:
            tray.run()
        except KeyboardInterrupt:
            server.should_exit = True
    else:
        server.run()

if __name__ == "__main__":
    main()
