# Imagen de la API - Sistema de Asistencia y Nomina
# Build en dos etapas para que las herramientas de compilacion no queden
# en la imagen final.

# ---- etapa 1: dependencias ----
FROM python:3.11-slim AS builder

WORKDIR /build

# gcc lo necesita bcrypt al instalarse; se queda en esta etapa
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

# Primero requirements.txt para aprovechar la cache de Docker
COPY requirements.txt .

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ---- etapa 2: imagen final ----
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# La API no corre como root
RUN useradd --create-home --shell /bin/bash appuser

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv
COPY --chown=appuser:appuser . .

# La BD va en su propia carpeta: /app es de root y appuser no puede crear
# archivos ahi. Ademas asi los datos sobreviven al cambiar el contenedor.
ENV DB_DIR=/app/data \
    DB_FILE=/app/data/sistema.db \
    DATABASE_URL=sqlite:////app/data/sistema.db

RUN mkdir -p "$DB_DIR" && chown -R appuser:appuser "$DB_DIR"

VOLUME ["/app/data"]

USER appuser

EXPOSE 8000

# La imagen slim no trae curl, se usa python para el chequeo
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/')" || exit 1

# Si la BD no existe (primer arranque) se corre el seed. exec para que
# uvicorn sea PID 1 y responda a docker stop.
CMD ["sh", "-c", "if [ ! -f \"$DB_FILE\" ]; then echo 'Base de datos no encontrada: ejecutando seed inicial...'; python -m app.seed || echo 'Aviso: el seed no se completo; la API arranca sin datos.'; fi; exec uvicorn main:app --host 0.0.0.0 --port 8000"]
