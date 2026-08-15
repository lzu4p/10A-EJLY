"""Endpoints publicos de SOLO LECTURA (sin token).

Pensados para revisar la informacion rapido en el navegador y tomar capturas,
o para que otro proyecto consuma los datos sin autenticarse.
"""
from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.deps import get_db
from app.models import Usuario, Empleado, Asistencia
from app.schemas import EmpleadoOut

router = APIRouter(prefix="/publico", tags=["Publico (solo lectura, sin token)"])


def _usuario_dict(u: Usuario) -> dict:
    # Incluye la contrasena en formato HASH (bcrypt). El hash NO puede
    # revertirse al texto original, por eso es seguro mostrarlo como evidencia
    # de que las contrasenas se guardan encriptadas.
    return {
        "id": u.id,
        "username": u.username,
        "password": u.password,
        "nombre": u.nombre,
        "tipo": u.tipo,
        "empleado_id": u.empleado_id,
    }


def _asistencia_dict(a: Asistencia) -> dict:
    return {
        "id": a.id,
        "empleado_id": a.empleado_id,
        "empleado_nombre": a.empleado.nombre if a.empleado else None,
        "fecha": a.fecha.isoformat() if a.fecha else None,
        "hora_entrada": a.hora_entrada,
        "hora_salida": a.hora_salida,
        "estado": a.estado,
        "origen": a.origen,
    }


@router.get("/empleados", response_model=List[EmpleadoOut])
def empleados_publicos(db: Session = Depends(get_db)):
    return db.query(Empleado).order_by(Empleado.nombre).all()


@router.get("/asistencias")
def asistencias_publicas(db: Session = Depends(get_db)):
    registros = (
        db.query(Asistencia).order_by(Asistencia.fecha.desc(), Asistencia.id.desc()).all()
    )
    return [_asistencia_dict(a) for a in registros]


@router.get("/usuarios")
def usuarios_publicos(db: Session = Depends(get_db)):
    return [_usuario_dict(u) for u in db.query(Usuario).all()]


@router.get("")
def resumen_publico(db: Session = Depends(get_db)):
    """Todo en un solo JSON: usuarios, empleados y asistencias."""
    usuarios = db.query(Usuario).all()
    empleados = db.query(Empleado).order_by(Empleado.nombre).all()
    asistencias = (
        db.query(Asistencia).order_by(Asistencia.fecha.desc()).limit(50).all()
    )
    return {
        "usuarios": [_usuario_dict(u) for u in usuarios],
        "empleados": [
            {
                "id": e.id,
                "nombre": e.nombre,
                "puesto": e.puesto,
                "departamento": e.departamento,
                "salario_diario": e.salario_diario,
                "fecha_ingreso": e.fecha_ingreso.isoformat() if e.fecha_ingreso else None,
                "activo": e.activo,
                "usuario_id": e.usuario_id,
            }
            for e in empleados
        ],
        "asistencias_recientes": [_asistencia_dict(a) for a in asistencias],
    }
