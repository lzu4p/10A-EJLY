"""Carga inicial de la base de datos.

Uso:  python -m app.seed

Genera:
  - Usuarios de acceso (se intentan importar de MockAPI; si no hay conexion,
    se usa el respaldo local).
  - Empleados de la organizacion.
  - Historial de asistencia de las ultimas 3 semanas, para que el modulo de
    nomina tenga datos con los que calcular desde el primer arranque.
"""
import random
from datetime import datetime, date, timedelta

import requests

from app.config import MOCKAPI_BASE, HORA_LIMITE_ENTRADA
from app.database import Base, engine, SessionLocal
from app.models import Usuario, Empleado, Asistencia
from app.security import hash_password

# Semilla fija: el historial generado es siempre el mismo, de modo que las
# capturas de pantalla y las pruebas sean reproducibles.
random.seed(20260815)

# Usuarios de respaldo (contrasenas de demostracion, NO reales).
RESPALDO_USERS = [
    {"id": "1", "username": "izu", "password": "admin123",
     "nombre": "Luis Ramirez", "tipo": "admin"},
    {"id": "2", "username": "username 2", "password": "password 2",
     "nombre": "nombre 2", "tipo": "user"},
]

# Plantilla de empleados. El primero se vincula al usuario administrador para
# poder demostrar el registro de asistencia desde la propia app.
EMPLEADOS = [
    ("Luis Alfredo Ramirez Huerta",   "Jefe de Sistemas",     "Sistemas",       850.0, "2024-01-15", 1),
    ("Jose Armando Sanchez Patricio", "Desarrollador",        "Sistemas",       620.0, "2024-03-01", None),
    ("Yohan Arturo Escobedo Sandoval", "Analista",            "Sistemas",       580.0, "2024-05-20", None),
    ("Maria Fernanda Lopez",          "Contadora",            "Administracion", 700.0, "2023-11-10", None),
    ("Carlos Mendez Ruiz",            "Auxiliar Contable",    "Administracion", 450.0, "2025-02-03", None),
    ("Ana Sofia Torres",              "Recursos Humanos",     "Administracion", 660.0, "2024-08-18", None),
    ("Miguel Angel Herrera",          "Almacenista",          "Operaciones",    420.0, "2025-01-07", None),
    ("Diana Laura Vega",              "Supervisora de Turno", "Operaciones",    540.0, "2023-06-22", None),
]


def _fetch_usuarios():
    try:
        r = requests.get("{}/users".format(MOCKAPI_BASE), timeout=10)
        r.raise_for_status()
        data = r.json()
        print("  - usuarios: {} importados desde MockAPI".format(len(data)))
        return data
    except Exception as e:  # noqa: BLE001
        print("  - usuarios: sin conexion a MockAPI ({}); usando respaldo".format(e))
        return RESPALDO_USERS


def _normalizar_tipo(t):
    t = str(t or "").lower().strip()
    return t if t in ("admin", "user") else "user"


def _generar_asistencias(db, empleados):
    """Historial de las ultimas 3 semanas, solo dias habiles."""
    hoy = date.today()
    inicio = hoy - timedelta(days=20)
    total = 0

    for emp in empleados:
        dia = inicio
        while dia <= hoy:
            # weekday(): 5 = sabado, 6 = domingo -> no se laboran.
            if dia.weekday() < 5:
                sorteo = random.random()

                if sorteo < 0.06:
                    # Falta: no se registran horas y no se paga el dia.
                    registro = Asistencia(
                        empleado_id=emp.id, fecha=dia,
                        hora_entrada=None, hora_salida=None,
                        estado="falta", origen="admin",
                    )
                else:
                    if sorteo < 0.22:
                        # Retardo: entra despues de la hora limite.
                        hora_e = "{:02d}:{:02d}".format(9, random.randint(6, 45))
                    else:
                        hora_e = "{:02d}:{:02d}".format(8, random.randint(20, 58))

                    hora_s = "{:02d}:{:02d}".format(
                        random.choice([17, 17, 18]), random.randint(0, 59)
                    )
                    estado = "presente" if hora_e <= HORA_LIMITE_ENTRADA else "retardo"
                    registro = Asistencia(
                        empleado_id=emp.id, fecha=dia,
                        hora_entrada=hora_e, hora_salida=hora_s,
                        estado=estado,
                        origen="app" if random.random() < 0.7 else "admin",
                    )

                db.add(registro)
                total += 1
            dia += timedelta(days=1)

    return total


def seed():
    print("Recreando base de datos...")
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        # --- Usuarios ---
        for u in _fetch_usuarios():
            db.add(Usuario(
                id=int(u["id"]),
                username=u.get("username", ""),
                password=hash_password(u.get("password", "")),  # hasheada (bcrypt)
                nombre=u.get("nombre", ""),
                tipo=_normalizar_tipo(u.get("tipo")),
                fecha_creado=datetime.utcnow(),
            ))
        db.commit()

        # --- Empleados ---
        creados = []
        for nombre, puesto, depto, salario, ingreso, usuario_id in EMPLEADOS:
            emp = Empleado(
                nombre=nombre,
                puesto=puesto,
                departamento=depto,
                salario_diario=salario,
                fecha_ingreso=datetime.strptime(ingreso, "%Y-%m-%d").date(),
                activo=1,
                usuario_id=usuario_id,
            )
            db.add(emp)
            creados.append(emp)
        db.commit()
        for emp in creados:
            db.refresh(emp)
        print("  - empleados: {} creados".format(len(creados)))

        # --- Asistencia ---
        total = _generar_asistencias(db, creados)
        db.commit()
        print("  - asistencias: {} registros de los ultimos 20 dias".format(total))

        print("Seed completado. Las contrasenas se almacenaron hasheadas (bcrypt).")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
