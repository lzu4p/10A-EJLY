from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.deps import get_db, get_current_user
from app.models import Usuario
from app.schemas import UsuarioPublico, UsuarioUpdate, UsuarioCreate
from app.security import hash_password

router = APIRouter(prefix="/usuarios", tags=["Usuarios"])

TIPOS_VALIDOS = {"admin", "user"}


@router.get("", response_model=List[UsuarioPublico])
def listar(
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    return db.query(Usuario).all()


@router.post("", response_model=UsuarioPublico, status_code=status.HTTP_201_CREATED)
def crear(
    datos: UsuarioCreate,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    username = datos.username.strip()
    if db.query(Usuario).filter(Usuario.username == username).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="El nombre de usuario ya existe",
        )
    tipo = (datos.tipo or "user").lower().strip()
    user = Usuario(
        username=username,
        password=hash_password(datos.password),  # se guarda hasheada (bcrypt)
        nombre=datos.nombre,
        tipo=tipo if tipo in TIPOS_VALIDOS else "user",
        fecha_creado=datetime.utcnow(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.put("/{usuario_id}", response_model=UsuarioPublico)
def actualizar(
    usuario_id: int,
    datos: UsuarioUpdate,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    user = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado",
        )

    if datos.nombre is not None:
        user.nombre = datos.nombre
    if datos.username is not None and datos.username.strip():
        user.username = datos.username.strip()
    if datos.tipo is not None:
        tipo = datos.tipo.lower().strip()
        user.tipo = tipo if tipo in TIPOS_VALIDOS else "user"
    # Contraseña: solo se actualiza si llega un valor no vacío.
    if datos.password is not None and datos.password != "":
        user.password = hash_password(datos.password)

    db.commit()
    db.refresh(user)
    return user
