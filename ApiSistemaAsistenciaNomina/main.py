from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import Base, engine
from app.routers import auth, usuarios, productos, publico

# Crea las tablas si no existen (el seed las recrea con datos).
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="API Sistema de Asistencia y Nómina",
    description=(
        "API REST con autenticación por token JWT.\n\n"
        "- El token se genera en /login y se reemplaza en cada nuevo login.\n"
        "- Todas las operaciones CRUD requieren el token en el header "
        "`Authorization: Bearer <token>`.\n"
        "- /logout elimina el token; si el cliente se cierra o crashea, el "
        "token caduca solo por expiración."
    ),
    version="1.0.0",
)

# CORS abierto para que la app Flutter (y Swagger) puedan consumir la API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(usuarios.router)
app.include_router(productos.router)
app.include_router(publico.router)


@app.get("/", tags=["Estado"])
def raiz():
    return {
        "servicio": "API Sistema de Asistencia y Nómina",
        "estado": "ok",
        "documentacion": "/docs",
    }
