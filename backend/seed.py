from sqlalchemy import select

from auth import hash_password
from config import settings
from database import AsyncSessionLocal
from models import AdminAccount, Outlet, Restaurant


async def seed_local_admin() -> None:
    """Create one local owner account so fallback login works immediately."""
    if not settings.LOCAL_SEED_ADMIN:
        return

    async with AsyncSessionLocal() as db:
        restaurant = (
            await db.execute(
                select(Restaurant).where(Restaurant.id == settings.LOCAL_RESTAURANT_ID)
            )
        ).scalar_one_or_none()
        if restaurant is None:
            restaurant = Restaurant(
                id=settings.LOCAL_RESTAURANT_ID,
                name=settings.LOCAL_RESTAURANT_NAME,
            )
            db.add(restaurant)
            await db.flush()
        else:
            restaurant.name = settings.LOCAL_RESTAURANT_NAME

        outlet = (
            await db.execute(select(Outlet).where(Outlet.id == settings.LOCAL_OUTLET_ID))
        ).scalar_one_or_none()
        if outlet is None:
            outlet = Outlet(
                id=settings.LOCAL_OUTLET_ID,
                restaurant_id=restaurant.id,
                name=settings.LOCAL_OUTLET_NAME,
                server_id=settings.LOCAL_SERVER_ID,
            )
            db.add(outlet)
            await db.flush()
        else:
            outlet.restaurant_id = restaurant.id
            outlet.name = settings.LOCAL_OUTLET_NAME
            outlet.server_id = settings.LOCAL_SERVER_ID

        account = (
            await db.execute(
                select(AdminAccount).where(
                    (AdminAccount.email == settings.LOCAL_ADMIN_EMAIL)
                    | (AdminAccount.username == settings.LOCAL_ADMIN_USERNAME)
                )
            )
        ).scalar_one_or_none()
        if account is None:
            account = AdminAccount(
                outlet_id=outlet.id,
                email=settings.LOCAL_ADMIN_EMAIL.lower(),
                username=settings.LOCAL_ADMIN_USERNAME.lower(),
                password_hash=hash_password(settings.LOCAL_ADMIN_PASSWORD),
            )
            db.add(account)
        else:
            account.outlet_id = outlet.id
            account.email = settings.LOCAL_ADMIN_EMAIL.lower()
            account.username = settings.LOCAL_ADMIN_USERNAME.lower()
            account.password_hash = hash_password(settings.LOCAL_ADMIN_PASSWORD)

        await db.commit()
