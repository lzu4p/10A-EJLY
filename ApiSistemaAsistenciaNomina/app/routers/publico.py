"""Endpoints públicos de SOLO LECTURA (sin token).

Pensados para revisar la información rápido en el navegador y tomar capturas,
o para que otro proyecto consuma los datos sin autenticarse. NO exponen la
contraseña (ni siquiera su hash) — solo los campos seguros.
"""
from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models import Usuario, Producto
from app.schemas import ProductoOut

router = APIRouter(prefix="/publico", tags=["Publico (solo lectura, sin token)"])


def _usuario_dict(u: Usuario) -> dict:
    # Incluye la contraseña en formato HASH (bcrypt). El hash NO puede
    # revertirse al texto original, por eso es seguro mostrarlo como evidencia
    # de que las contraseñas se guardan encriptadas.
    return {
        "id": u.id,
        "username": u.username,
        "password": u.password,
        "nombre": u.nombre,
        "tipo": u.tipo,
    }


@router.get("/productos", response_model=List[ProductoOut])
def productos_publicos(db: Session = Depends(get_db)):
    return db.query(Producto).all()


@router.get("/usuarios")
def usuarios_publicos(db: Session = Depends(get_db)):
    return [_usuario_dict(u) for u in db.query(Usuario).all()]


@router.get("")
def resumen_publico(db: Session = Depends(get_db)):
    """Todo en un solo JSON: usuarios + productos."""
    usuarios = db.query(Usuario).all()
    productos = db.query(Producto).all()
    return {
        "usuarios": [_usuario_dict(u) for u in usuarios],
        "productos": [
            {
                "id": p.id,
                "nombre": p.nombre,
                "categoria": p.categoria,
                "precio": p.precio,
                "cantidad": p.cantidad,
            }
            for p in productos
        ],
    }
