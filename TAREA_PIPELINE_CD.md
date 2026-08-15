# Pipeline CI/CD — Sistema de Asistencia y Nómina

**Materia:** Gestión del Proceso de Desarrollo de Software — 3er Parcial, Unidad III
**Equipo:** Jose Armando Sanchez Patricio · Luis Alfredo Ramirez Huerta · Yohan Arturo Escobedo Sandoval

**Archivos entregados:**

| Archivo | Contenido |
|---|---|
| `.github/workflows/ci.yml` | Pipeline completo CI + CD en YAML |
| `ApiSistemaAsistenciaNomina/Dockerfile` | Imagen Docker de la API |
| `ApiSistemaAsistenciaNomina/.dockerignore` | Exclusiones del contexto de build |

---

## Nota previa: qué se dockeriza en este sistema

El proyecto tiene **dos componentes** y cada uno produce un artefacto distinto:

| Componente | Artefacto | ¿Se dockeriza? |
|---|---|---|
| App **Flutter** | APK release | **No.** Un APK se instala en Android; un contenedor no ejecuta aplicaciones móviles. Su artefacto se publica como archivo descargable. |
| API **Python/FastAPI** | Imagen Docker | **Sí.** Es un servicio de servidor: exactamente el caso de uso de los contenedores. |

Por eso el `Dockerfile` corresponde a la API. La app Flutter permanece en la fase
CI, donde se compila y se publica el APK como artefacto del pipeline.

---

## Parte 1 — Justificación de los steps del CI

### Job `build-and-test` (app Flutter)

| Step | Justificación |
|---|---|
| `actions/checkout@v4` | Descarga el código del repositorio en el runner. Sin este paso el runner está vacío. |
| `subosito/flutter-action@v2` | Instala el SDK de Flutter. El runner de GitHub no lo trae preinstalado. |
| `flutter pub get` | Descarga las dependencias declaradas en `pubspec.yaml`. |
| `dart format --set-exit-if-changed` | Verifica el formato del código. La bandera hace que el pipeline **falle** si hay diferencias: convierte el estilo en requisito, no en sugerencia, y evita que los *pull requests* se ensucien con cambios de espaciado. |
| `flutter analyze` | Análisis estático: detecta errores de tipo, variables sin usar e incumplimientos de las reglas de lint antes de compilar. |
| `flutter test --coverage` | Ejecuta las pruebas y genera el reporte de cobertura. |
| `upload-artifact` (coverage) | Conserva `lcov.info` como evidencia descargable de la cobertura alcanzada. |
| `flutter build apk --release` | Compila el APK de producción: **el artefacto de la app**. |
| `upload-artifact` (APK) | Publica el APK como artefacto descargable del pipeline. |

**Orden de los pasos:** formato → análisis → pruebas → compilación. Es deliberado:
lo más rápido y barato falla primero. No tiene sentido esperar varios minutos a
que compile el APK para descubrir que faltaba un punto y coma.

### Job `test-api` (API Python)

| Step | Justificación |
|---|---|
| `actions/setup-python@v5` | Instala Python 3.11, la misma versión que usa la imagen Docker. Validar con la versión de destino evita el clásico "funciona en mi máquina". |
| `pip install -r requirements.txt` | Instala las dependencias de la API. |
| Arrancar `uvicorn` + `curl --fail` | Prueba de humo: comprueba que la API levanta y responde. Si no arranca, no tiene sentido empaquetarla en una imagen. |

Este job corre **en paralelo** con el de Flutter porque son independientes: así el
pipeline tarda lo que el más lento, no la suma de ambos.

---

## Parte 2 — Justificación de los steps del CD

### Job `docker-build-push` — requisitos 1 y 2 de la tarea

| Elemento | Justificación |
|---|---|
| `needs: [build-and-test, test-api]` | **Encadenamiento.** La imagen solo se construye si *todas* las pruebas pasaron. Impide publicar una versión defectuosa. |
| Condición de rama `main` | **Requisito 4.** Solo `main` publica. `develop` se queda en CI: valida sin llegar al registro. |
| `docker/setup-buildx-action@v3` | Habilita BuildKit: cache de capas y compilación multi-plataforma (necesario si la imagen debe correr en Raspberry Pi, que es ARM). |
| `docker/login-action@v3` | Autentica contra `docker.io`. Las credenciales vienen de **GitHub Secrets**, nunca escritas en el YAML. |
| `docker/build-push-action@v6` | **Steps 1 y 2 juntos:** construye la imagen y la sube al registro en una sola acción. |
| Etiqueta `latest` | Referencia móvil a la última versión estable. |
| Etiqueta con el SHA del commit | Identifica el commit exacto. **Permite rollback preciso:** si la versión nueva falla, se vuelve al SHA anterior con un solo comando. |
| `cache-from/to: type=gha` | Reutiliza capas entre ejecuciones. Reduce el tiempo de build de minutos a segundos cuando solo cambia el código. |

### Job `deploy-staging` — requisito 3 de la tarea

| Elemento | Justificación |
|---|---|
| `needs: docker-build-push` | No se puede desplegar una imagen que no se publicó. |
| Condición de rama `main` | **Requisito 4**, aplicado también al deploy. |
| `environment: staging` | Registra el despliegue en la pestaña *Environments* de GitHub: historial de qué versión se desplegó y cuándo. |
| Step *Verificar configuración* | Comprueba si el servidor ya está configurado como Secret. Evita que el pipeline se ponga en rojo mientras el entorno físico aún no existe. |
| `appleboy/ssh-action` | **Step 3:** entra por SSH al servidor de staging y ejecuta el despliegue. |
| `docker pull` de la etiqueta SHA | Descarga **exactamente** la imagen que se acaba de construir, no la etiqueta móvil (que podría haber cambiado entre el build y el deploy). |
| `docker stop/rm` tolerante a fallo | Elimina el contenedor anterior sin fallar en el primer despliegue, cuando aún no hay contenedor previo. |
| `--restart unless-stopped` | Si el servidor se reinicia, el contenedor vuelve solo. |
| `SECRET_KEY` por variable de entorno | La clave de firma de los JWT se inyecta desde un Secret: no viaja dentro de la imagen. |
| Step *Verificar que staging responde* | Prueba de humo posterior al deploy. **Sin este paso el pipeline diría "éxito" aunque la API hubiera quedado caída.** |

### Job `notify-on-failure`

| Elemento | Justificación |
|---|---|
| `needs: [todos los jobs]` | Vigila la cadena completa, no solo la compilación. |
| `if: always()` combinado con la búsqueda de fallos | `always()` es necesario porque, por defecto, un job cuyas dependencias fallaron se cancela — y un job cancelado no notificaría nada. |
| Webhook de Discord vía Secret | La URL del webhook **es una credencial**: quien la posee puede publicar en el canal. Va en Secrets, no en el YAML. |

---

## Parte 3 — Justificación del Dockerfile

### Build multi-etapa

| Etapa | Justificación |
|---|---|
| **1. `builder`** | Instala `gcc` (necesario para compilar *bcrypt*) y crea el entorno virtual con las dependencias. |
| **2. `runtime`** | Copia únicamente el entorno virtual ya construido. **`gcc` no llega a la imagen final:** menor tamaño y menor superficie de ataque, porque un atacante no encuentra un compilador dentro del contenedor. |

### Instrucciones clave

| Instrucción | Justificación |
|---|---|
| `FROM python:3.11-slim` | Variante *slim*: incluye Python sin paquetes del sistema innecesarios. |
| `COPY requirements.txt` **antes** que el código | **Cache de capas.** Docker reutiliza la capa de dependencias mientras `requirements.txt` no cambie. Si se copiara el código primero, cualquier cambio menor obligaría a reinstalar todo. |
| `PYTHONDONTWRITEBYTECODE=1` | Evita archivos `.pyc` dentro del contenedor. |
| `PYTHONUNBUFFERED=1` | Los logs salen inmediatamente; sin esto, `docker logs` mostraría la salida a destiempo. |
| `useradd appuser` + `USER appuser` | **Principio de menor privilegio.** La API no corre como root: si alguien explotara una vulnerabilidad de la aplicación, no obtendría control administrativo del contenedor. |
| `mkdir /app/data` + `chown appuser` | **Corrige un error real detectado al probar la imagen.** `WORKDIR /app` crea el directorio como *root*; `COPY --chown` solo cambia el dueño de los archivos copiados, no el del directorio. Al cambiar a `appuser`, SQLite no podía crear `sistema.db` y fallaba con *"unable to open database file"*. La base de datos se traslada a un directorio propio con el dueño correcto. |
| `VOLUME ["/app/data"]` | Los datos **no deben vivir en la capa de imagen**. En un volumen sobreviven al reemplazo del contenedor: cada despliegue sustituye el código sin borrar la información. |
| `EXPOSE 8000` | Documenta el puerto de escucha. |
| `HEALTHCHECK` | Docker consulta el endpoint raíz cada 30 s. Un orquestador puede detectar el contenedor caído y reiniciarlo automáticamente. |
| `CMD` con seed condicional | En el primer arranque (volumen vacío) ejecuta el *seed* para que la API tenga usuarios y productos iniciales. En arranques posteriores lo omite: así un reinicio **no borra** los datos existentes. |
| `exec uvicorn` en el `CMD` | `exec` hace que uvicorn sea el proceso principal (PID 1) y reciba las señales del sistema. Sin él, `docker stop` no cerraría limpiamente la aplicación. |
| `--host 0.0.0.0` en el `CMD` | Sin esto, uvicorn solo escucharía dentro del contenedor y sería inaccesible desde fuera. |

### Evidencia de la imagen ya probada

| Verificación | Resultado |
|---|---|
| Construcción de la imagen | Correcta — 282 MB |
| Usuario en ejecución | `uid=1000(appuser)` — **no root** |
| Seed automático en el primer arranque | 2 usuarios y 3 productos importados |
| `HEALTHCHECK` | Estado `healthy` |
| CRUD **sin** token | `HTTP 403` (rechazado) |
| CRUD **con** token | `HTTP 200` |
| Persistencia tras `docker restart` | El *seed* no se repite: los datos permanecen |

### `.dockerignore`

Excluye `venv/`, `__pycache__/`, `*.db`, `*.log`, `.env` y `.git/`. Dos motivos:
reduce el tamaño del contexto de build, y sobre todo **evita filtrar datos locales
o secretos** dentro de una imagen que se publica en un registro público.

---

## Parte 4 — Diagrama del flujo

```
                    push a develop  ──────┐         push a main
                                          │              │
                                          ▼              ▼
                        ┌───────────────────────────────────────┐
                        │  FASE CI  (ambas ramas, en paralelo)  │
                        │  ┌─────────────────┐ ┌──────────────┐ │
                        │  │ Flutter         │ │ API Python   │ │
                        │  │ formato→analyze │ │ instalar     │ │
                        │  │ →tests→build    │ │ →arrancar    │ │
                        │  │ ⇒ APK           │ │ →responder   │ │
                        │  └─────────────────┘ └──────────────┘ │
                        └───────────────────────────────────────┘
                                          │              │
                              (develop    │              │
                               termina    │              ▼
                                aquí) ────┘   ┌──────────────────────┐
                                              │  FASE CD  (solo main)│
                                              │                      │
                                              │  1. docker build     │
                                              │  2. docker push      │
                                              │     → docker.io      │
                                              │     latest + sha     │
                                              │          │           │
                                              │          ▼           │
                                              │  3. deploy staging   │
                                              │     ssh → pull       │
                                              │         → run        │
                                              │         → smoke test │
                                              └──────────────────────┘
                                                         │
                                                         ▼
                                              [Aprobación manual del
                                               líder → producción]

  Cualquier fallo en cualquier punto  ⇒  notificación automática a Discord
```

**Aprobación manual a producción:** por tratarse de un sistema de **nómina**, un
despliegue defectuoso afecta directamente el cálculo del pago de los empleados.
Staging se despliega automáticamente (retroalimentación rápida); producción exige
revisión humana mediante *required reviewers* en GitHub Environments. El costo de
esa aprobación son minutos; el costo de un error en nómina es mucho mayor.
