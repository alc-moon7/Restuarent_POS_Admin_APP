import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from config import settings

ALGORITHM = "HS256"
TOKEN_EXPIRE_DAYS = 365

bearer_scheme = HTTPBearer(auto_error=False)
PBKDF2_ITERATIONS = 210_000


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        PBKDF2_ITERATIONS,
    ).hex()
    return f"pbkdf2_sha256${PBKDF2_ITERATIONS}${salt}${digest}"


def verify_password(plain: str, hashed: str) -> bool:
    try:
        scheme, iterations, salt, expected = hashed.split("$", 3)
        if scheme != "pbkdf2_sha256":
            return False
        digest = hashlib.pbkdf2_hmac(
            "sha256",
            plain.encode("utf-8"),
            salt.encode("utf-8"),
            int(iterations),
        ).hex()
        return hmac.compare_digest(digest, expected)
    except Exception:
        return False


def create_device_token(outlet_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=TOKEN_EXPIRE_DAYS)
    return jwt.encode(
        {"sub": outlet_id, "exp": expire},
        settings.SECRET_KEY,
        algorithm=ALGORITHM,
    )


def decode_device_token(token: str) -> str:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        outlet_id: str = payload.get("sub", "")
        if not outlet_id:
            raise ValueError
        return outlet_id
    except (JWTError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")


def get_current_outlet_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> str:
    if credentials is None:
        if settings.ALLOW_LOCAL_FALLBACK_AUTH_BYPASS:
            return "local_fallback"
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing token")
    try:
        return decode_device_token(credentials.credentials)
    except HTTPException:
        if settings.ALLOW_LOCAL_FALLBACK_AUTH_BYPASS:
            return "local_fallback"
        raise
