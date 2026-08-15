from datetime import datetime

from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    Date,
    DateTime,
    ForeignKey,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship

from app.database import Base


class Usuario(Base):
    """Cuenta de acceso al sistema (login)."""

    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    password = Column(String, nullable=False)          # hash bcrypt, nunca texto plano
    nombre = Column(String, nullable=False, default="")
    tipo = Column(String, nullable=False, default="user")  # "admin" | "user"
    fecha_creado = Column(DateTime, default=datetime.utcnow)

    # --- Sesión activa (token único por usuario) ---
    # Se guarda el identificador del token vigente. Un login nuevo lo reemplaza,
    # un logout lo borra. Si no coincide con el del request -> 401.
    token_jti = Column(String, nullable=True)
    token_expira = Column(DateTime, nullable=True)

    # Un usuario puede tener (o no) un empleado asociado. Si lo tiene, puede
    # registrar su propia asistencia desde la app.
    empleado = relationship("Empleado", back_populates="usuario", uselist=False)

    @property
    def empleado_id(self):
        """Expone el id del empleado vinculado (o None).

        Permite que el esquema UsuarioPublico lo incluya automaticamente sin
        tener que armar el diccionario a mano en cada endpoint.
        """
        return self.empleado.id if self.empleado else None


class Empleado(Base):
    """Persona que labora en la organizacion y por la que se calcula nomina."""

    __tablename__ = "empleados"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String, nullable=False, default="")
    puesto = Column(String, nullable=False, default="")
    departamento = Column(String, nullable=False, default="")
    # Base del calculo de nomina: total = dias trabajados * salario_diario.
    salario_diario = Column(Float, nullable=False, default=0)
    fecha_ingreso = Column(Date, nullable=True)
    # Baja logica: no se borra el historial de asistencia de un ex-empleado.
    activo = Column(Integer, nullable=False, default=1)  # 1 = activo, 0 = baja

    # Vinculo opcional con una cuenta de acceso.
    usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=True, unique=True)
    usuario = relationship("Usuario", back_populates="empleado")

    asistencias = relationship(
        "Asistencia", back_populates="empleado", cascade="all, delete-orphan"
    )


class Asistencia(Base):
    """Registro de un dia laboral de un empleado."""

    __tablename__ = "asistencias"
    # Un empleado no puede tener dos registros del mismo dia.
    __table_args__ = (
        UniqueConstraint("empleado_id", "fecha", name="uq_asistencia_empleado_fecha"),
    )

    id = Column(Integer, primary_key=True, index=True)
    empleado_id = Column(Integer, ForeignKey("empleados.id"), nullable=False, index=True)
    fecha = Column(Date, nullable=False, index=True)

    # Se guardan como texto "HH:MM": simple de leer, sin problemas de zona horaria.
    hora_entrada = Column(String, nullable=True)
    hora_salida = Column(String, nullable=True)

    # "presente" | "retardo" | "falta"
    # Se calcula al registrar la entrada comparando contra HORA_LIMITE_ENTRADA.
    estado = Column(String, nullable=False, default="presente")

    # Quien capturo el registro: "app" (el propio empleado) o "admin" (captura manual).
    origen = Column(String, nullable=False, default="app")

    empleado = relationship("Empleado", back_populates="asistencias")
