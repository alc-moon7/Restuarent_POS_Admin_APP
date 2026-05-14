from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_outlet_id
from database import get_db
from models import Device
from schemas import DeviceHeartbeatRequest, DeviceRegisterRequest, ok

router = APIRouter()


@router.post("/devices/register")
async def register_device(
    body: DeviceRegisterRequest,
    outlet_id: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    existing = (
        await db.execute(
            select(Device).where(
                (Device.outlet_id == outlet_id) & (Device.server_id == body.serverId)
            )
        )
    ).scalar_one_or_none()

    if existing is None:
        device = Device(outlet_id=outlet_id, server_id=body.serverId)
        db.add(device)
        await db.commit()

    return ok({"registered": True})


@router.post("/devices/heartbeat")
async def heartbeat_device(
    body: DeviceHeartbeatRequest,
    outlet_id: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    existing = (
        await db.execute(
            select(Device).where(
                (Device.outlet_id == outlet_id) & (Device.server_id == body.serverId)
            )
        )
    ).scalar_one_or_none()

    if existing is None:
        device = Device(outlet_id=outlet_id, server_id=body.serverId)
        db.add(device)
        await db.commit()

    return ok(
        {
            "alive": True,
            "serverId": body.serverId,
            "restaurantId": body.restaurantId,
            "outletId": body.outletId,
            "localIp": body.localIp,
            "port": body.port,
            "localServerRunning": body.localServerRunning,
        }
    )
