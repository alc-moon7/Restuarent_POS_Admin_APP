"""Public customer-facing endpoints — no device token required."""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from database import get_db
from models import MenuItem, Order, Outlet, Restaurant
from routers.ws import manager

router = APIRouter(prefix="/customer", tags=["customer"])


# ── helpers ────────────────────────────────────────────────────────────────────

def _ok(data):
    return {"ok": True, "data": data}


def _item_to_dict(item: MenuItem) -> dict:
    return {
        "id": item.id,
        "name": item.name,
        "description": item.description or "",
        "price": float(item.price),
        "category": item.category or "General",
        "isAvailable": item.is_available,
        "imageUrl": item.image_url,
        "videoUrl": item.video_url,
    }


async def _get_outlet(outlet_id: str, db: AsyncSession) -> Outlet:
    outlet = (
        await db.execute(select(Outlet).where(Outlet.id == outlet_id))
    ).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=404, detail="Outlet not found")
    return outlet


# ── GET menu ──────────────────────────────────────────────────────────────────

@router.get("/{outlet_id}/menu")
async def get_public_menu(
    outlet_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Return available menu items for the customer-facing menu page."""
    await _get_outlet(outlet_id, db)
    items = (
        await db.execute(
            select(MenuItem)
            .where(
                MenuItem.outlet_id == outlet_id,
                MenuItem.is_available == True,
                MenuItem.deleted_at == None,
            )
            .order_by(MenuItem.category, MenuItem.name)
        )
    ).scalars().all()
    return _ok([_item_to_dict(i) for i in items])


# ── POST order ────────────────────────────────────────────────────────────────

class CustomerOrderItem(BaseModel):
    menuItemId: str
    name: str
    qty: int
    price: float


class CustomerOrderRequest(BaseModel):
    items: list[CustomerOrderItem]
    customerName: str | None = None
    tableNo: str | None = None
    note: str | None = None


@router.post("/{outlet_id}/orders")
async def place_customer_order(
    outlet_id: str,
    body: CustomerOrderRequest,
    db: AsyncSession = Depends(get_db),
):
    """Place an order from the customer menu web app."""
    if not body.items:
        raise HTTPException(status_code=422, detail="Order must contain at least one item")

    await _get_outlet(outlet_id, db)

    menu_ids = [item.menuItemId for item in body.items]
    db_items = (
        await db.execute(
            select(MenuItem).where(
                MenuItem.outlet_id == outlet_id,
                MenuItem.id.in_(menu_ids),
                MenuItem.deleted_at == None,
            )
        )
    ).scalars().all()
    menu_by_id = {item.id: item for item in db_items}

    items_payload = []
    total = 0.0
    for requested in body.items:
        if requested.qty <= 0:
            raise HTTPException(status_code=422, detail="Item quantity must be greater than zero")
        menu_item = menu_by_id.get(requested.menuItemId)
        if menu_item is None:
            raise HTTPException(status_code=404, detail=f"Menu item not found: {requested.menuItemId}")
        if not menu_item.is_available:
            raise HTTPException(status_code=409, detail=f"Menu item unavailable: {menu_item.name}")
        price = float(menu_item.price)
        line_total = round(price * requested.qty, 2)
        total += line_total
        items_payload.append(
            {
                "id": str(uuid.uuid4()),
                "orderId": "",
                "menuItemId": menu_item.id,
                "name": menu_item.name,
                "qty": requested.qty,
                "price": price,
                "lineTotal": line_total,
            }
        )

    now = datetime.now(timezone.utc)
    order_id = str(uuid.uuid4())
    for item in items_payload:
        item["orderId"] = order_id

    order = Order(
        id=order_id,
        outlet_id=outlet_id,
        source="customer_web",
        status="pending",
        total_amount=round(total, 2),
        items=items_payload,
        notes=body.note or (body.tableNo and f"Table {body.tableNo}"),
        created_at=now,
        updated_at=now,
    )
    db.add(order)
    await db.commit()
    await db.refresh(order)

    # Assign a 1-based serial number scoped to this outlet
    count_res = await db.execute(
        select(func.coalesce(func.max(Order.serial_number), 0)).where(
            Order.outlet_id == outlet_id,
            Order.id != order.id,
        )
    )
    order.serial_number = int(count_res.scalar() or 0) + 1
    await db.commit()

    # Broadcast to the admin POS via WebSocket
    await manager.broadcast(
        outlet_id,
        {
            "type": "order_created",
            "data": {
                "id": order.id,
                "orderNo": f"ORD-{order.serial_number}",
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
            },
        },
    )

    return _ok({
        "orderId": order.id,
        "id": order.id,
        "orderNo": f"ORD-{order.serial_number}",
        "serialNumber": order.serial_number,
        "sequenceNo": order.serial_number,
        "status": order.status,
        "totalAmount": float(order.total_amount),
        "total": float(order.total_amount),
        "items": order.items,
        "note": order.notes,
        "notes": order.notes,
    })


# ── GET restaurant info ────────────────────────────────────────────────────────

@router.get("/{outlet_id}/info")
async def get_outlet_info(
    outlet_id: str,
    db: AsyncSession = Depends(get_db),
):
    """Return restaurant/outlet name for display on the customer menu page."""
    outlet = (
        await db.execute(
            select(Outlet)
            .where(Outlet.id == outlet_id)
            .options(joinedload(Outlet.restaurant))
        )
    ).scalar_one_or_none()
    if outlet is None:
        raise HTTPException(status_code=404, detail="Outlet not found")
    return _ok({
        "outletId": outlet.id,
        "restaurantName": outlet.restaurant.name if outlet.restaurant else "",
        "outletName": outlet.name,
        "bannerUrl": outlet.banner_url,
        "videoUrl": outlet.video_url,
        "galleryImages": outlet.gallery_images or [],
    })
