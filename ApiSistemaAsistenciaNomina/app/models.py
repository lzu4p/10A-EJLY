from datetime import datetime

from sqlalchemy import Column, Integer, String, Float, DateTime

from app.database import Base


class Usuario(Base):
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


class Producto(Base):
    __tablename__ = "productos"

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String, nullable=False, default="")
    categoria = Column(String, nullable=False, default="")
    precio = Column(Float, nullable=False, default=0)
    cantidad = Column(Integer, nullable=False, default=0)
