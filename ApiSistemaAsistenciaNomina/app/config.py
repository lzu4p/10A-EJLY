import os

# Clave para firmar los JWT. En producción se define por variable de entorno.
SECRET_KEY = os.getenv(
    "SECRET_KEY",
    "cambia-esta-clave-secreta-en-produccion-0a1b2c3d4e5f6g7h",
)
ALGORITHM = "HS256"

# Vida del token. Si el cliente crashea/cierra sin avisar, el token caduca solo.
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

# Base de datos local (SQLite, sin servicios externos).
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./sistema.db")

# Origen de los datos para el seed inicial.
MOCKAPI_BASE = os.getenv(
    "MOCKAPI_BASE",
    "https://65f3ab00105614e654a0cefb.mockapi.io",
)
