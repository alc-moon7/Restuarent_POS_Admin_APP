from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str = "sqlite+aiosqlite:///./local_pos.db"
    SECRET_KEY: str = "change-me"
    IMAGES_DIR: str = "./uploads/menu_images"
    OUTLET_IMAGES_DIR: str = "./uploads/outlet_images"
    OUTLET_VIDEOS_DIR: str = "./uploads/outlet_videos"
    VIDEO_MAX_BYTES: int = 50 * 1024 * 1024  # 50 MB
    BASE_URL: str = "http://localhost:8000"

    LOCAL_SEED_ADMIN: bool = True
    LOCAL_SERVER_ID: str = "local_server"
    LOCAL_RESTAURANT_ID: str = "rest_local"
    LOCAL_OUTLET_ID: str = "outlet_local"
    LOCAL_RESTAURANT_NAME: str = "Moon Test 4"
    LOCAL_OUTLET_NAME: str = "Main Outlet"
    LOCAL_ADMIN_EMAIL: str = "zero@moonx.dev"
    LOCAL_ADMIN_USERNAME: str = "moonx"
    LOCAL_ADMIN_PASSWORD: str = "moonxadmin@"
    ALLOW_LOCAL_FALLBACK_AUTH_BYPASS: bool = True

    NGROK_AUTHTOKEN: str = ""
    NGROK_STATIC_DOMAIN: str = ""


settings = Settings()
