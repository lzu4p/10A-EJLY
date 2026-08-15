# =============================================================================
# Dockerfile - API Sistema de Asistencia y Nomina (FastAPI)
# Build multi-etapa: separa la instalacion de dependencias de la imagen final,
# de modo que las herramientas de compilacion no viajan a produccion.
# =============================================================================

# ----------------------------- ETAPA 1: builder ------------------------------
# Instala las dependencias dentro de un entorno virtual aislado.
FROM python:3.11-slim AS builder

WORKDIR /build

# gcc solo se necesita para compilar algunas dependencias (bcrypt); queda
# encerrado en esta etapa y NO llega a la imagen final.
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

# Se copia primero requirements.txt (y no todo el codigo) para aprovechar la
# cache de capas de Docker: si el codigo cambia pero las dependencias no,
# esta capa se reutiliza y el build es mucho mas rapido.
COPY requirements.txt .

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ----------------------------- ETAPA 2: runtime ------------------------------
# Imagen final: solo Python + el entorno virtual ya construido + el codigo.
FROM python:3.11-slim AS runtime

# PYTHONDONTWRITEBYTECODE: evita archivos .pyc dentro del contenedor.
# PYTHONUNBUFFERED: los logs salen al instante (necesario para `docker logs`).
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Principio de menor privilegio: la API corre como usuario sin permisos de
# root. Si alguien lograra explotar la aplicacion, no seria administrador
# del contenedor. (Checklist de seguridad - Clase 4)
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

# Se traen las dependencias ya instaladas desde la etapa builder.
COPY --from=builder /opt/venv /opt/venv

# Codigo de la aplicacion (el .dockerignore excluye venv, *.db, __pycache__).
COPY --chown=appuser:appuser . .

# La base de datos vive en su propio directorio, NO en /app.
# Motivo tecnico: /app pertenece a root, y appuser (sin privilegios) no puede
# crear archivos nuevos ahi; SQLite fallaria con "unable to open database file".
# Motivo de diseno: los datos no deben vivir en la capa de imagen, sino en un
# volumen, para que sobrevivan al reemplazo del contenedor en cada despliegue.
ENV DB_DIR=/app/data \
    DB_FILE=/app/data/sistema.db \
    DATABASE_URL=sqlite:////app/data/sistema.db

RUN mkdir -p "$DB_DIR" && chown -R appuser:appuser "$DB_DIR"

# Punto de montaje para persistir la base de datos entre despliegues.
VOLUME ["/app/data"]

USER appuser

# Documenta el puerto en el que escucha la API.
EXPOSE 8000

# Verificacion de salud: Docker consulta el endpoint raiz cada 30s para saber
# si el contenedor sigue respondiendo. Un orquestador puede reiniciarlo solo.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/')" || exit 1

# Arranque:
#   1. Si la base de datos aun no existe (primer despliegue o volumen nuevo),
#      ejecuta el seed para que la API tenga usuarios y productos iniciales.
#      Si el seed falla, se registra el aviso pero la API igual arranca.
#   2. `exec` hace que uvicorn sea el proceso principal (PID 1) y reciba las
#      senales del sistema: sin el, `docker stop` no cerraria limpiamente.
#   3. 0.0.0.0 permite recibir conexiones desde fuera del contenedor.
CMD ["sh", "-c", "if [ ! -f \"$DB_FILE\" ]; then echo 'Base de datos no encontrada: ejecutando seed inicial...'; python -m app.seed || echo 'Aviso: el seed no se completo; la API arranca sin datos.'; fi; exec uvicorn main:app --host 0.0.0.0 --port 8000"]
