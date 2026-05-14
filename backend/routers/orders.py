from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import get_current_outlet_id
from database import get_db
from models import Order
from routers.ws import manager
from schemas import OrderPayload, OrderStatusUpdate, ok

router = APIRouter()


def _order_to_dict(order: Order) -> dict:
    return {
        "id": order.id,
        "orderNo": f"ORD-{order.serial_number or order.created_at.strftime('%H%M%S')}",
        "outletId": order.outlet_id,
        "serialNumber": order.serial_number,
        "sequenceNo": order.serial_number,
        "source": order.source,
        "status": order.status,
        "total": float(order.total_amount),
        "totalAmount": float(order.total_amount),
        "items": order.items,
        "note": order.notes,
        "notes": order.notes,
        "createdAt": order.created_at.isoformat(),
        "updatedAt": order.updated_at.isoformat(),
    }


async def _next_serial(outlet_id: str, db: AsyncSession) -> int:
    result = await db.execute(
        select(func.coalesce(func.max(Order.serial_number), 0)).where(
            Order.outlet_id == outlet_id
        )
    )
    return int(result.scalar() or 0) + 1


@router.get("/outlets/{outlet_id}/orders")
async def pull_orders(
    outlet_id: str,
    since: str | None = None,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    query = select(Order).where(Order.outlet_id == outlet_id).order_by(Order.created_at.desc())
    if since:
        dt = datetime.fromisoformat(since.replace("Z", "+00:00"))
        query = query.where(Order.updated_at > dt)
    orders = (await db.execute(query)).scalars().all()
    return ok([_order_to_dict(o) for o in orders])


@router.get("/outlets/{outlet_id}/orders/{order_id}")
async def get_order(
    outlet_id: str,
    order_id: str,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
):
    order = (
        await db.execute(
            select(Order).where((Order.outlet_id == outlet_id) & (Order.id == order_id))
        )
    ).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")
    return ok(_order_to_dict(order))


@router.post("/outlets/{outlet_id}/orders")
async def push_order(
    outlet_id: str,
    body: OrderPayload,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    existing = (await db.execute(select(Order).where(Order.id == body.id))).scalar_one_or_none()
    if existing:
        return ok(_order_to_dict(existing))

    now = datetime.now(timezone.utc)
    serial_number = body.serialNumber or await _next_serial(outlet_id, db)
    order = Order(
        id=body.id,
        outlet_id=outlet_id,
        serial_number=serial_number,
        source=body.source,
        status=body.status,
        total_amount=body.total if body.total is not None else body.totalAmount,
        items=body.items,
        notes=body.note or body.notes,
        created_at=now,
        updated_at=now,
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)

    await manager.broadcast(outlet_id, {"type": "order_created", "data": _order_to_dict(order)})
    return ok(_order_to_dict(order))


@router.patch("/outlets/{outlet_id}/orders/{order_id}/status")
async def update_order_status(
    outlet_id: str,
    order_id: str,
    body: OrderStatusUpdate,
    current_outlet: str = Depends(get_current_outlet_id),
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(None, alias="Idempotency-Key"),
):
    order = (await db.execute(select(Order).where(Order.id == order_id))).scalar_one_or_none()
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found.")

    order.status = body.status
    order.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(order)

    await manager.broadcast(outlet_id, {"type": "order_status_updated", "data": _order_to_dict(order)})
    return ok(_order_to_dict(order))
