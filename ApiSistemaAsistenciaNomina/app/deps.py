from datetime import datetime
from typing import Generator

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import Usuario
from app.security import decodificar_token

bearer_scheme = HTTPBearer(auto_error=True)


def get_db() -> Generator:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(
    cred: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> Usuario:
    """Valida el token del header Authorization: Bearer <token>.

    Rechaza si: firma inválida, expirado, usuario inexistente, o si el jti
    no coincide con la sesión activa guardada (logout / login en otro lado).
    """
    no_autorizado = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o sesión expirada",
        headers={"WWW-Authenticate": "Bearer"},
    )

    token = cred.credentials
    try:
        payload = decodificar_token(token)
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expirado",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except jwt.PyJWTError:
        raise no_autorizado

    user_id = payload.get("sub")
    jti = payload.get("jti")
    if user_id is None or jti is None:
        raise no_autorizado

    user = db.query(Usuario).filter(Usuario.id == int(user_id)).first()
    if user is None:
        raise no_autorizado

    # Sesión única: el token presentado debe ser el último emitido.
    if user.token_jti != jti:
        raise no_autorizado

    # Defensa extra del lado servidor (además del exp del JWT).
    if user.token_expira is None or user.token_expira < datetime.utcnow():
        raise no_autorizado

    return user
