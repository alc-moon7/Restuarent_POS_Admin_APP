# Local POS

Flutter Restaurant POS Admin/Server app for running a local restaurant server
from an admin device. Customer Flutter or React clients can connect over the
same WiFi using HTTP and WebSocket APIs. Internet is not required.

## Run

```sh
flutter pub get
flutter run
```

## API

Default server port: `8080`

```js
fetch("http://ADMIN_LOCAL_IP:8080/menu");

fetch("http://ADMIN_LOCAL_IP:8080/orders", {
  method: "POST",
  headers: {"Content-Type": "application/json"},
  body: JSON.stringify({
    customerName: "Moon",
    tableNo: "A1",
    items: [{menuItemId: "MENU_ITEM_ID", qty: 2}]
  })
});

const ws = new WebSocket("ws://ADMIN_LOCAL_IP:8080/ws");
```

## Endpoints

- `GET /health`
- `GET /menu`
- `GET /menu?includeUnavailable=true`
- `POST /orders`
- `GET /orders`
- `PATCH /orders/:id/status`
- `WS /ws`
