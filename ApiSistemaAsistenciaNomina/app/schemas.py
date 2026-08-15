from datetime import date
from typing import List, Optional

from pydantic import BaseModel


# ---------- Autenticación ----------
class LoginRequest(BaseModel):
    username: str
    password: str


class UsuarioPublico(BaseModel):
    id: int
    username: str
    nombre: str
    tipo: str
    # Si la cuenta tiene un empleado asociado, la app muestra el boton de checar.
    empleado_id: Optional[int] = None

    class Config:
        from_attributes = True


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expira_en_minutos: int
    usuario: UsuarioPublico


# ---------- Usuarios ----------
class UsuarioCreate(BaseModel):
    nombre: str
    username: str
    password: str
    tipo: Optional[str] = "user"    # "admin" | "user"


class UsuarioUpdate(BaseModel):
    nombre: Optional[str] = None
    username: Optional[str] = None
    password: Optional[str] = None  # vacío o ausente = no cambiar
    tipo: Optional[str] = None      # "admin" | "user"


# ---------- Empleados ----------
class EmpleadoBase(BaseModel):
    nombre: str
    puesto: str
    departamento: str
    salario_diario: float
    fecha_ingreso: Optional[date] = None
    activo: int = 1
    usuario_id: Optional[int] = None


class EmpleadoCreate(EmpleadoBase):
    pass


class EmpleadoUpdate(BaseModel):
    nombre: Optional[str] = None
    puesto: Optional[str] = None
    departamento: Optional[str] = None
    salario_diario: Optional[float] = None
    fecha_ingreso: Optional[date] = None
    activo: Optional[int] = None
    usuario_id: Optional[int] = None


class EmpleadoOut(EmpleadoBase):
    id: int

    class Config:
        from_attributes = True


# ---------- Asistencia ----------
class AsistenciaBase(BaseModel):
    empleado_id: int
    fecha: date
    hora_entrada: Optional[str] = None   # "HH:MM"
    hora_salida: Optional[str] = None    # "HH:MM"
    estado: str = "presente"             # "presente" | "retardo" | "falta"


class AsistenciaCreate(AsistenciaBase):
    """Captura manual hecha por el administrador."""


class AsistenciaUpdate(BaseModel):
    hora_entrada: Optional[str] = None
    hora_salida: Optional[str] = None
    estado: Optional[str] = None


class AsistenciaOut(AsistenciaBase):
    id: int
    origen: str
    # Se incluye el nombre para que la app no tenga que cruzar tablas.
    empleado_nombre: Optional[str] = None

    class Config:
        from_attributes = True


class ChecadaResponse(BaseModel):
    """Resultado de marcar entrada o salida desde la app."""

    mensaje: str
    asistencia: AsistenciaOut


# ---------- Nómina ----------
class NominaDetalle(BaseModel):
    empleado_id: int
    empleado_nombre: str
    puesto: str
    departamento: str
    salario_diario: float
    dias_trabajados: int
    dias_retardo: int
    dias_falta: int
    total_pagar: float


class NominaResumen(BaseModel):
    periodo_inicio: date
    periodo_fin: date
    total_empleados: int
    total_dias_pagados: int
    total_nomina: float
    detalle: List[NominaDetalle]
