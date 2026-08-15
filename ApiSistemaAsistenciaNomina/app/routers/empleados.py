"""Modulo de Empleados: alta, consulta, edicion y baja logica."""
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.deps import get_db, get_current_user
from app.models import Usuario, Empleado
from app.schemas import EmpleadoOut, EmpleadoCreate, EmpleadoUpdate

router = APIRouter(prefix="/empleados", tags=["Empleados"])


@router.get("", response_model=List[EmpleadoOut])
def listar(
    solo_activos: bool = False,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    consulta = db.query(Empleado)
    if solo_activos:
        consulta = consulta.filter(Empleado.activo == 1)
    return consulta.order_by(Empleado.nombre).all()


@router.get("/{empleado_id}", response_model=EmpleadoOut)
def obtener(
    empleado_id: int,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    empleado = db.query(Empleado).filter(Empleado.id == empleado_id).first()
    if empleado is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Empleado no encontrado"
        )
    return empleado


@router.post("", response_model=EmpleadoOut, status_code=status.HTTP_201_CREATED)
def crear(
    datos: EmpleadoCreate,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    # Un usuario solo puede estar vinculado a un empleado.
    if datos.usuario_id is not None:
        ocupado = (
            db.query(Empleado).filter(Empleado.usuario_id == datos.usuario_id).first()
        )
        if ocupado:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ese usuario ya esta vinculado a otro empleado",
            )

    empleado = Empleado(**datos.model_dump())
    db.add(empleado)
    db.commit()
    db.refresh(empleado)
    return empleado


@router.put("/{empleado_id}", response_model=EmpleadoOut)
def actualizar(
    empleado_id: int,
    datos: EmpleadoUpdate,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    empleado = db.query(Empleado).filter(Empleado.id == empleado_id).first()
    if empleado is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Empleado no encontrado"
        )

    cambios = datos.model_dump(exclude_unset=True)

    if cambios.get("usuario_id") is not None:
        ocupado = (
            db.query(Empleado)
            .filter(
                Empleado.usuario_id == cambios["usuario_id"],
                Empleado.id != empleado_id,
            )
            .first()
        )
        if ocupado:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ese usuario ya esta vinculado a otro empleado",
            )

    for campo, valor in cambios.items():
        setattr(empleado, campo, valor)

    db.commit()
    db.refresh(empleado)
    return empleado


@router.delete("/{empleado_id}", status_code=status.HTTP_204_NO_CONTENT)
def dar_de_baja(
    empleado_id: int,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    """Baja LOGICA: conserva el historial de asistencia para la nomina."""
    empleado = db.query(Empleado).filter(Empleado.id == empleado_id).first()
    if empleado is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Empleado no encontrado"
        )
    empleado.activo = 0
    db.commit()
    return None
