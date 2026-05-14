# Hybrid POS Local Fallback Backend

This backend mirrors the Flutter Admin app cloud API contract, but runs locally.
Use it when the cloud API is unavailable or when testing the POS system on a LAN.

## What It Provides

- `GET /health`
- `POST /tenants/bootstrap`
- `POST /admin/login`
- `POST /admin/create`
- `POST /devices/register`
- `POST /devices/heartbeat`
- `GET /outlets/:outletId/menu`
- `POST /outlets/:outletId/menu/images`
- `POST /outlets/:outletId/menu`
- `PATCH /outlets/:outletId/menu/:id`
- `DELETE /outlets/:outletId/menu/:id`
- `GET /outlets/:outletId/orders`
- `GET /outlets/:outletId/orders/:id`
- `POST /outlets/:outletId/orders`
- `PATCH /outlets/:outletId/orders/:id/status`
- `WS /ws/:outletId?token=DEVICE_TOKEN`

## Run Locally

```bash
cd /home/moon-ahmed/Documents/GitHub/Restuarent_POS_Admin_APP/backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
bash start.sh
```

Default local URL:

```text
http://localhost:8000
```

For a real Android phone on the same WiFi, use the computer LAN IP instead:

```text
http://YOUR_COMPUTER_IP:8000
```

Example:

```text
http://192.168.0.105:8000
```

## Admin App Setup

In the Flutter Admin app:

1. Open `Settings`.
2. Open `Cloud Sync`.
3. Set `Cloud API URL` to your local backend URL.
4. Keep `Enable Cloud Sync` on.
5. Tap `Test Cloud`.
6. Create account or log in.

The same app can use either:

- Cloud: `https://vnhxfvtpkgykatvbrczn.supabase.co/functions/v1/pos-api`
- Local fallback: `http://YOUR_COMPUTER_IP:8000`

Recommended production setup:

- Keep `Cloud API URL` pointed to the real cloud API.
- Put this backend URL in `Local Fallback API URL`.
- The Admin app will try cloud first.
- If cloud/internet is unavailable, it mirrors local menu/orders to this fallback backend and imports fallback orders.
- Pending local sync events are not marked as cloud-synced by fallback success; when cloud returns, the app pushes them to cloud.

Build-time fallback URL is also supported:

```bash
flutter build apk --release \
  --dart-define=POS_CLOUD_API_URL=https://vnhxfvtpkgykatvbrczn.supabase.co/functions/v1/pos-api \
  --dart-define=POS_LOCAL_FALLBACK_API_URL=http://YOUR_COMPUTER_IP:8000 \
  --dart-define=POS_CLOUD_SYNC_ENABLED=true
```

## Default Local Admin

The local backend seeds one test admin account from `.env`:

```text
Email: zero@moonx.dev
Username: moonx
Password: moonxadmin@
Restaurant: Moon Test 4
Outlet: Main Outlet
```

Change these values in `.env` before real production use.

## Database

By default this backend uses SQLite:

```text
local_pos.db
```

If you want PostgreSQL later, change `DATABASE_URL` in `.env`:

```text
postgresql+asyncpg://USER:PASSWORD@localhost/DB_NAME
```

## Notes

- The local backend is a fallback server, not the public cloud deployment.
- Local phone access requires same WiFi and firewall allowing port `8000`.
- Menu image URLs use `BASE_URL`; set it to the LAN URL if phones need to load images.
- `ALLOW_LOCAL_FALLBACK_AUTH_BYPASS=true` is enabled by default so the cloud-issued device token can still talk to the LAN fallback server. Keep the fallback backend on a trusted private network.
