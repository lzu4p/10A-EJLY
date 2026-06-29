# API Sistema de Asistencia y Nómina

API REST en **Python (FastAPI)** con autenticación por **token JWT**, pensada para
sustituir a MockAPI en el login y las operaciones CRUD de la app Flutter
`SistemaAsistenciaNomina`.

## Características

- **Login con token**: `/login` valida credenciales y devuelve un JWT firmado.
- **CRUD protegido**: productos y usuarios exigen el header
  `Authorization: Bearer <token>`. Sin token válido → `401`.
- **Sesión única por usuario**: el servidor guarda el `jti` del último token
  emitido. Esto resuelve los 3 escenarios pedidos:
  | Escenario | Cómo se maneja |
  |-----------|----------------|
  | El usuario cierra sesión | `/logout` borra el `jti` → el token deja de servir al instante |
  | Login nuevo (otro dispositivo) | El login reemplaza el `jti` → el token anterior queda inválido |
  | Cierre de app / crash / reinicio sin avisar | El token caduca solo por `exp` (60 min por defecto); al reabrir, el cliente llama a `/me` y si recibe `401` fuerza re-login |
- **Contraseñas hasheadas** con bcrypt (nunca se devuelven ni se guardan en texto plano).
- **Datos importados de MockAPI** mediante el script de seed (mantiene coherencia).

## Requisitos

- Python 3.8+

## Instalación y ejecución (Windows / PowerShell)

```powershell
cd ApiSistemaAsistenciaNomina

python -m venv venv
venv\Scripts\activate

pip install -r requirements.txt

# Importa los datos de MockAPI a la base local (SQLite)
python -m app.seed

# Levanta el servidor
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

- Documentación interactiva (Swagger): http://localhost:8000/docs
- Desde el emulador Android, la API del host se accede en `http://10.0.2.2:8000`.

## Endpoints

| Método | Ruta | Token | Descripción |
|--------|------|:-----:|-------------|
| POST | `/login` | No | Devuelve `access_token` + datos del usuario |
| POST | `/logout` | Sí | Invalida el token actual |
| GET | `/me` | Sí | Valida el token y devuelve el usuario |
| GET | `/usuarios` | Sí | Lista usuarios |
| PUT | `/usuarios/{id}` | Sí | Edita nombre, usuario, contraseña y tipo (admin/user) |
| GET | `/productos` | Sí | Lista productos |
| POST | `/productos` | Sí | Crea producto |
| PUT | `/productos/{id}` | Sí | Edita producto |
| DELETE | `/productos/{id}` | Sí | Elimina producto |

## Diferencias respecto a MockAPI (a considerar al conectar Flutter)

1. **Login** ahora devuelve `{ access_token, usuario }` en vez de una lista.
   La app debe guardar `access_token` (en `EncryptedSharedPreferences` /
   `flutter_secure_storage`) y enviarlo en cada request.
2. **El password ya no se devuelve** en `GET /usuarios`. En el formulario de
   edición, dejar el campo contraseña vacío significa "no cambiar".
3. Las llamadas a `/productos` y `/usuarios` requieren el header
   `Authorization: Bearer <token>`.

## Configuración (variables de entorno opcionales)

| Variable | Valor por defecto |
|----------|-------------------|
| `SECRET_KEY` | clave de ejemplo (cambiar en producción) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` |
| `DATABASE_URL` | `sqlite:///./sistema.db` |
| `MOCKAPI_BASE` | endpoint MockAPI usado por el seed |
