from typing import Optional

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


# ---------- Productos ----------
class ProductoBase(BaseModel):
    nombre: str
    categoria: str
    precio: float
    cantidad: int


class ProductoCreate(ProductoBase):
    pass


class ProductoUpdate(BaseModel):
    nombre: Optional[str] = None
    categoria: Optional[str] = None
    precio: Optional[float] = None
    cantidad: Optional[int] = None


class ProductoOut(ProductoBase):
    id: int

    class Config:
        from_attributes = True
