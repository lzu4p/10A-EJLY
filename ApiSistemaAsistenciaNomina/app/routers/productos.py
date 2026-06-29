from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.deps import get_db, get_current_user
from app.models import Usuario, Producto
from app.schemas import ProductoOut, ProductoCreate, ProductoUpdate

router = APIRouter(prefix="/productos", tags=["Productos"])


@router.get("", response_model=List[ProductoOut])
def listar(
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    return db.query(Producto).all()


@router.post("", response_model=ProductoOut, status_code=status.HTTP_201_CREATED)
def crear(
    datos: ProductoCreate,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    producto = Producto(**datos.model_dump())
    db.add(producto)
    db.commit()
    db.refresh(producto)
    return producto


@router.put("/{producto_id}", response_model=ProductoOut)
def actualizar(
    producto_id: int,
    datos: ProductoUpdate,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    producto = db.query(Producto).filter(Producto.id == producto_id).first()
    if producto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Producto no encontrado",
        )
    for campo, valor in datos.model_dump(exclude_unset=True).items():
        setattr(producto, campo, valor)
    db.commit()
    db.refresh(producto)
    return producto


@router.delete("/{producto_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(
    producto_id: int,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    producto = db.query(Producto).filter(Producto.id == producto_id).first()
    if producto is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Producto no encontrado",
        )
    db.delete(producto)
    db.commit()
    return None
