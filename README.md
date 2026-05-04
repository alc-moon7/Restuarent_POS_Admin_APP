# REs Cloud Admin

Flutter Restaurant POS Admin app for cloud menu, order, sync, and realtime
management through Supabase Edge Functions.

## Multi-Restaurant Flow

This APK is built for selling to many restaurants. On first launch, each
restaurant enters only its restaurant and outlet name. The app calls
`POST /tenants/bootstrap`, creates a separate cloud restaurant/outlet identity,
and stores a private device token internally. Restaurant owners do not manually
paste Supabase keys, API keys, IP addresses, or ports.

## Run

```sh
flutter pub get
flutter run
```

## Android Release

Create a private upload keystore first:

```sh
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
cp android/key.properties.example android/key.properties
```

Then edit `android/key.properties` with the same passwords used in `keytool`.
Never commit `android/key.properties` or `.jks` files.

Build Play Store app bundle:

```sh
flutter build appbundle --release
```

Build release APK:

```sh
flutter build apk --release
```

The Supabase cloud API URL is built into the app by default. To override it for
staging or another project, pass `POS_CLOUD_API_URL`:

```sh
flutter build apk --release \
  --dart-define=POS_CLOUD_API_URL=https://vnhxfvtpkgykatvbrczn.supabase.co/functions/v1/pos-api \
  --dart-define=POS_CLOUD_SYNC_ENABLED=true
```

The app reads Supabase Realtime config from `GET /health`, so no manual Device
token/API key is required in Settings. The private device token is issued by the
backend during the first restaurant setup.

## Cloud

Cloud API:

```txt
https://vnhxfvtpkgykatvbrczn.supabase.co/functions/v1/pos-api
```

First-run setup endpoint:

```txt
POST /tenants/bootstrap
```

Cloud realtime uses Supabase Realtime Broadcast topic:

```txt
pos:outlet:<outletId>
```

Customer websites should call the cloud API directly; this app no longer hosts a
local LAN HTTP/WebSocket server.
