from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.config import ACCESS_TOKEN_EXPIRE_MINUTES
from app.deps import get_db, get_current_user
from app.models import Usuario
from app.schemas import LoginRequest, LoginResponse, UsuarioPublico
from app.security import verify_password, crear_token

router = APIRouter(tags=["Autenticacion"])


@router.post("/login", response_model=LoginResponse)
def login(datos: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(Usuario).filter(Usuario.username == datos.username).first()
    if user is None or not verify_password(datos.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuario o contraseña incorrectos",
        )

    token, jti, expira = crear_token(user.id)

    # Reemplaza cualquier sesión previa: el token anterior queda invalidado.
    user.token_jti = jti
    user.token_expira = expira
    db.commit()
    db.refresh(user)

    return LoginResponse(
        access_token=token,
        expira_en_minutos=ACCESS_TOKEN_EXPIRE_MINUTES,
        usuario=UsuarioPublico.model_validate(user),
    )


@router.post("/logout")
def logout(
    user: Usuario = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Borra la sesión activa: el token deja de ser válido inmediatamente.
    user.token_jti = None
    user.token_expira = None
    db.commit()
    return {"detail": "Sesión cerrada correctamente"}


@router.get("/me", response_model=UsuarioPublico)
def me(user: Usuario = Depends(get_current_user)):
    # Permite al cliente validar si el token guardado sigue vigente
    # (al reabrir la app tras cerrarla o un reinicio del sistema).
    return UsuarioPublico.model_validate(user)
