"""Importa los datos actuales de MockAPI a la base local SQLite.

Uso:  python -m app.seed

Si no hay conexión a MockAPI, usa los datos de respaldo (snapshot tomado
al crear el proyecto) para no dejar la base vacía.
"""
from datetime import datetime

import requests

from app.config import MOCKAPI_BASE
from app.database import Base, engine, SessionLocal
from app.models import Usuario, Producto
from app.security import hash_password

# Snapshot de respaldo (por si MockAPI no responde).
RESPALDO_USERS = [
    {"id": "1", "username": "izu", "password": "Ch1bPek020!",
     "nombre": "Luis Ramirez", "tipo": "admin"},
    {"id": "2", "username": "username 2", "password": "password 2",
     "nombre": "nombre 2", "tipo": "user"},
]
RESPALDO_PRODUCTOS = [
    {"id": "1", "nombre": "Mermelada de Fresa", "categoria": "Alimentos",
     "precio": 37, "cantidad": 145},
    {"id": "2", "nombre": "Barra de Pan Integral", "categoria": "Alimentos",
     "precio": 48, "cantidad": 54},
    {"id": "3", "nombre": "Agua", "categoria": "Alimento",
     "precio": 19, "cantidad": 12},
]


def _fetch(endpoint, respaldo):
    try:
        r = requests.get("{}/{}".format(MOCKAPI_BASE, endpoint), timeout=10)
        r.raise_for_status()
        data = r.json()
        print("  - {}: {} registros importados desde MockAPI".format(endpoint, len(data)))
        return data
    except Exception as e:  # noqa: BLE001
        print("  - {}: sin conexión a MockAPI ({}); usando respaldo".format(endpoint, e))
        return respaldo


def _normalizar_tipo(t):
    t = str(t or "").lower().strip()
    return t if t in ("admin", "user") else "user"


def seed():
    print("Recreando base de datos...")
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        for u in _fetch("users", RESPALDO_USERS):
            db.add(Usuario(
                id=int(u["id"]),
                username=u.get("username", ""),
                password=hash_password(u.get("password", "")),  # se guarda hasheada
                nombre=u.get("nombre", ""),
                tipo=_normalizar_tipo(u.get("tipo")),
                fecha_creado=datetime.utcnow(),
            ))

        for p in _fetch("productos", RESPALDO_PRODUCTOS):
            db.add(Producto(
                id=int(p["id"]),
                nombre=p.get("nombre", ""),
                categoria=p.get("categoria", ""),
                precio=float(p.get("precio", 0)),
                cantidad=int(p.get("cantidad", 0)),
            ))

        db.commit()
        print("Seed completado. Las contraseñas se almacenaron hasheadas (bcrypt).")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
