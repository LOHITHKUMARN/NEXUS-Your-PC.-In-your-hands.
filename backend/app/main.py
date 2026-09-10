import socket
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from zeroconf import Zeroconf, ServiceInfo

from app.config import settings, get_lan_ip
from app.core.security import verify_api_key
from app.core.websocket_manager import ws_manager
from app.routers import telemetry, audio, media, display, power, apps, extras, auth, input

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("pc_control.main")

zeroconf_instance = None
service_info = None

def register_zeroconf():
    global zeroconf_instance, service_info
    try:
        zeroconf_instance = Zeroconf()
        hostname = socket.gethostname()
        local_ip = get_lan_ip()

        service_info = ServiceInfo(
            settings.SERVICE_TYPE,
            f"{hostname}.{settings.SERVICE_TYPE}",
            addresses=[socket.inet_aton(local_ip)],
            port=settings.PORT,
            properties={"version": "1.0.0", "hostname": hostname},
            server=f"{hostname}.local."
        )
        zeroconf_instance.register_service(service_info)
        logger.info(f"mDNS Zeroconf service registered: {hostname} at {local_ip}:{settings.PORT}")
    except Exception as e:
        logger.warning(f"Failed to register Zeroconf mDNS service: {e}")

def unregister_zeroconf():
    global zeroconf_instance, service_info
    if zeroconf_instance and service_info:
        try:
            zeroconf_instance.unregister_service(service_info)
            zeroconf_instance.close()
            logger.info("mDNS Zeroconf service unregistered.")
        except Exception:
            pass

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("Initializing PC Control Center backend...")
    register_zeroconf()
    await ws_manager.start_broadcaster()
    yield
    # Shutdown
    logger.info("Shutting down PC Control Center backend...")
    await ws_manager.stop_broadcaster()
    unregister_zeroconf()

app = FastAPI(
    title="PC Control Center API",
    description="Windows Host Backend for PC Control Center (Phone & Tablet App)",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for Flutter web / emulator clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API Routers
app.include_router(auth.router)
app.include_router(telemetry.router)
app.include_router(audio.router)
app.include_router(media.router)
app.include_router(display.router)
app.include_router(power.router)
app.include_router(apps.router)
app.include_router(extras.router)
app.include_router(input.router)

from app.services.system_service import system_service

@app.get("/")
async def root_status():
    return {
        "status": "online",
        "service": settings.SERVICE_NAME,
        "version": "1.2.0",
        "port": settings.PORT,
        "hostname": socket.gethostname(),
        "lan_ip": get_lan_ip(),
        "mac_address": system_service.get_mac_address(),
        "api_key_configured": bool(settings.API_KEY)
    }

@app.get("/api/discovery/info")
async def discovery_info():
    """Unauthenticated discovery endpoint for mobile clients scanning LAN."""
    return {
        "service": settings.SERVICE_NAME,
        "hostname": socket.gethostname(),
        "lan_ip": get_lan_ip(),
        "mac_address": system_service.get_mac_address(),
        "port": settings.PORT,
        "version": "1.2.0",
        "api_key_required": bool(settings.API_KEY)
    }

@app.get("/api/system/audit-log", dependencies=[Depends(verify_api_key)])
async def get_audit_log(limit: int = 50):
    """Returns rolling security & session activity audit events."""
    from app.services.audit_service import audit_service
    events = audit_service.get_events(limit)
    return {
        "count": len(events),
        "events": events
    }

