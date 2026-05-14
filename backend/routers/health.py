from fastapi import APIRouter
from config import settings

router = APIRouter()


@router.get("/health")
async def health():
    realtime = {
        "enabled": False,
        "supabaseUrl": "",
        "publishableKey": "",
        "channelPrefix": "pos:outlet:",
    }
    return {
        "ok": True,
        "server": "hybrid-pos-local-fallback",
        "mode": "local",
        "database": True,
        "baseUrl": settings.BASE_URL,
        "wsPath": "/ws/{outletId}",
        "realtime": {
            **realtime,
            "events": [
                "device_registered",
                "device_heartbeat",
                "menu_updated",
                "order_created",
                "order_status_updated",
            ],
        },
        "data": {"status": "ok", "realtime": realtime},
        "error": None,
    }
