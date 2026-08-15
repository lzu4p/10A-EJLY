"""Modulo de Asistencia.

Dos formas de registrar (opcion 1c del diseno):
  - El propio empleado marca entrada/salida desde la app  -> /asistencias/checar
  - El administrador captura manualmente                  -> POST /asistencias
"""
from datetime import date as Date, datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.config import HORA_LIMITE_ENTRADA
from app.deps import get_db, get_current_user
from app.models import Usuario, Empleado, Asistencia
from app.schemas import (
    AsistenciaOut,
    AsistenciaCreate,
    AsistenciaUpdate,
    ChecadaResponse,
)

router = APIRouter(prefix="/asistencias", tags=["Asistencia"])

ESTADOS_VALIDOS = {"presente", "retardo", "falta"}


def _clasificar(hora_entrada: str) -> str:
    """Presente si llego a tiempo; retardo si paso la hora limite."""
    return "presente" if hora_entrada <= HORA_LIMITE_ENTRADA else "retardo"


def _salida(a: Asistencia) -> AsistenciaOut:
    """Convierte el modelo a esquema agregando el nombre del empleado."""
    return AsistenciaOut(
        id=a.id,
        empleado_id=a.empleado_id,
        fecha=a.fecha,
        hora_entrada=a.hora_entrada,
        hora_salida=a.hora_salida,
        estado=a.estado,
        origen=a.origen,
        empleado_nombre=a.empleado.nombre if a.empleado else None,
    )


def _empleado_del_usuario(db: Session, usuario: Usuario) -> Empleado:
    empleado = db.query(Empleado).filter(Empleado.usuario_id == usuario.id).first()
    if empleado is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Tu cuenta no tiene un empleado asociado. "
                "Pide al administrador que la vincule."
            ),
        )
    return empleado


# --------------------------------------------------------------------------
# Consulta
# --------------------------------------------------------------------------
@router.get("", response_model=List[AsistenciaOut])
def listar(
    fecha: Optional[Date] = Query(None, description="Filtra por dia (YYYY-MM-DD)"),
    empleado_id: Optional[int] = Query(None),
    desde: Optional[Date] = Query(None),
    hasta: Optional[Date] = Query(None),
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    consulta = db.query(Asistencia)
    if fecha is not None:
        consulta = consulta.filter(Asistencia.fecha == fecha)
    if empleado_id is not None:
        consulta = consulta.filter(Asistencia.empleado_id == empleado_id)
    if desde is not None:
        consulta = consulta.filter(Asistencia.fecha >= desde)
    if hasta is not None:
        consulta = consulta.filter(Asistencia.fecha <= hasta)

    registros = consulta.order_by(
        Asistencia.fecha.desc(), Asistencia.id.desc()
    ).all()
    return [_salida(a) for a in registros]


@router.get("/hoy", response_model=Optional[AsistenciaOut])
def mi_asistencia_de_hoy(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(get_current_user),
):
    """Estado de la checada del usuario en el dia actual (para la app)."""
    empleado = _empleado_del_usuario(db, usuario)
    registro = (
        db.query(Asistencia)
        .filter(
            Asistencia.empleado_id == empleado.id,
            Asistencia.fecha == Date.today(),
        )
        .first()
    )
    return _salida(registro) if registro else None


# --------------------------------------------------------------------------
# Registro desde la app (el propio empleado)
# --------------------------------------------------------------------------
@router.post("/checar", response_model=ChecadaResponse)
def checar_entrada(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(get_current_user),
):
    empleado = _empleado_del_usuario(db, usuario)
    hoy = Date.today()

    existente = (
        db.query(Asistencia)
        .filter(Asistencia.empleado_id == empleado.id, Asistencia.fecha == hoy)
        .first()
    )
    if existente is not None and existente.hora_entrada:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya registraste tu entrada hoy a las {}".format(
                existente.hora_entrada
            ),
        )

    hora = datetime.now().strftime("%H:%M")
    if existente is None:
        existente = Asistencia(empleado_id=empleado.id, fecha=hoy, origen="app")
        db.add(existente)

    existente.hora_entrada = hora
    existente.estado = _clasificar(hora)
    db.commit()
    db.refresh(existente)

    return ChecadaResponse(
        mensaje="Entrada registrada a las {} ({})".format(hora, existente.estado),
        asistencia=_salida(existente),
    )


@router.post("/checar-salida", response_model=ChecadaResponse)
def checar_salida(
    db: Session = Depends(get_db),
    usuario: Usuario = Depends(get_current_user),
):
    empleado = _empleado_del_usuario(db, usuario)
    hoy = Date.today()

    registro = (
        db.query(Asistencia)
        .filter(Asistencia.empleado_id == empleado.id, Asistencia.fecha == hoy)
        .first()
    )
    if registro is None or not registro.hora_entrada:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Primero debes registrar tu entrada",
        )
    if registro.hora_salida:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya registraste tu salida hoy a las {}".format(registro.hora_salida),
        )

    hora = datetime.now().strftime("%H:%M")
    registro.hora_salida = hora
    db.commit()
    db.refresh(registro)

    return ChecadaResponse(
        mensaje="Salida registrada a las {}".format(hora),
        asistencia=_salida(registro),
    )


# --------------------------------------------------------------------------
# Captura manual (administrador)
# --------------------------------------------------------------------------
@router.post("", response_model=AsistenciaOut, status_code=status.HTTP_201_CREATED)
def capturar(
    datos: AsistenciaCreate,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    empleado = db.query(Empleado).filter(Empleado.id == datos.empleado_id).first()
    if empleado is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Empleado no encontrado"
        )

    duplicado = (
        db.query(Asistencia)
        .filter(
            Asistencia.empleado_id == datos.empleado_id,
            Asistencia.fecha == datos.fecha,
        )
        .first()
    )
    if duplicado:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ese empleado ya tiene un registro en esa fecha",
        )

    estado = datos.estado if datos.estado in ESTADOS_VALIDOS else "presente"
    registro = Asistencia(
        empleado_id=datos.empleado_id,
        fecha=datos.fecha,
        hora_entrada=datos.hora_entrada,
        hora_salida=datos.hora_salida,
        estado=estado,
        origen="admin",
    )
    db.add(registro)
    db.commit()
    db.refresh(registro)
    return _salida(registro)


@router.put("/{asistencia_id}", response_model=AsistenciaOut)
def actualizar(
    asistencia_id: int,
    datos: AsistenciaUpdate,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    registro = db.query(Asistencia).filter(Asistencia.id == asistencia_id).first()
    if registro is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Registro no encontrado"
        )

    cambios = datos.model_dump(exclude_unset=True)
    if "estado" in cambios and cambios["estado"] not in ESTADOS_VALIDOS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Estado invalido. Use: presente, retardo o falta",
        )

    for campo, valor in cambios.items():
        setattr(registro, campo, valor)

    db.commit()
    db.refresh(registro)
    return _salida(registro)


@router.delete("/{asistencia_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar(
    asistencia_id: int,
    db: Session = Depends(get_db),
    _: Usuario = Depends(get_current_user),
):
    registro = db.query(Asistencia).filter(Asistencia.id == asistencia_id).first()
    if registro is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Registro no encontrado"
        )
    db.delete(registro)
    db.commit()
    return None
