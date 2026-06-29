import uuid
from datetime import datetime, timedelta, timezone
from typing import Tuple

import bcrypt
import jwt

from app.config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES


def hash_password(plain: str) -> str:
    # bcrypt opera sobre máximo 72 bytes.
    return bcrypt.hashpw(plain.encode("utf-8")[:72], bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8")[:72], hashed.encode("utf-8"))
    except (ValueError, TypeError):
        return False


def crear_token(user_id: int) -> Tuple[str, str, datetime]:
    """Genera un JWT firmado. Devuelve (token, jti, fecha_expira_utc_naive)."""
    jti = uuid.uuid4().hex
    now = datetime.now(timezone.utc)
    expira = now + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": str(user_id),
        "jti": jti,
        "iat": int(now.timestamp()),
        "exp": int(expira.timestamp()),
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    # PyJWT devuelve str en >=2.0
    return token, jti, expira.replace(tzinfo=None)


def decodificar_token(token: str) -> dict:
    """Valida firma y expiración. Lanza jwt.PyJWTError si es inválido."""
    return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
