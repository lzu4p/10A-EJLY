# Proyecto P3 — Liberación, Despliegue y Monitoreo
## Sistema de Control de Asistencia y Nómina

**Materia:** Gestión del Proceso de Desarrollo de Software — 3er Parcial, Unidad III
**Grupo:** 10A
**Repositorio:** https://github.com/lzu4p/10A-EJLY

### Integrantes

| Integrante | Rol en el proyecto |
|---|---|
| Luis Alfredo Ramirez Huerta | Módulo de asistencia y seguridad · Pipeline CI/CD · API |
| Jose Armando Sanchez Patricio | Módulo de empleados · Documentación |
| Yohan Arturo Escobedo Sandoval | Módulo de nómina · Pruebas |

> *Ajustar los roles según lo acordado por el equipo.*

---

## 1. Qué se desarrolló

Un sistema de **control de asistencia y cálculo de nómina** compuesto por dos
aplicaciones que se comunican entre sí:

| Componente | Tecnología | Función |
|---|---|---|
| **Aplicación móvil** | Flutter (Dart) | Interfaz de usuario: registro de asistencia, gestión de empleados y consulta de nómina |
| **API REST** | Python (FastAPI) | Lógica de negocio, autenticación por token y persistencia de datos |

### Arquitectura general

```
   ┌──────────────────────┐        HTTP + JSON        ┌─────────────────────┐
   │   App Flutter        │  ──────────────────────▶  │   API FastAPI       │
   │   (Android)          │   Authorization: Bearer   │   (Python 3.11)     │
   │                      │  ◀──────────────────────  │                     │
   │  • Login             │                           │  • JWT / bcrypt     │
   │  • Asistencia        │                           │  • Reglas de negocio│
   │  • Empleados         │                           │  • SQLAlchemy       │
   │  • Nómina            │                           └──────────┬──────────┘
   │  • Usuarios          │                                      │
   │                      │                           ┌──────────▼──────────┐
   │  Token cifrado en    │                           │   SQLite            │
   │  EncryptedShared-    │                           │   (volumen Docker)  │
   │  Preferences         │                           └─────────────────────┘
   └──────────────────────┘
```

### Módulos implementados

| Módulo | Qué hace |
|---|---|
| **Autenticación** | Login con token JWT, sesión única por usuario, cierre de sesión que invalida el token en el servidor |
| **Asistencia** | Registro de entrada/salida por el propio empleado **y** captura manual por el administrador |
| **Empleados** | Alta, consulta, edición y baja lógica. Incluye puesto, departamento y salario diario |
| **Nómina** | Cálculo por periodo: días trabajados × salario diario |
| **Usuarios** | Administración de cuentas de acceso y roles (admin / user) |

---

## 2. Flujo del módulo

### 2.1 Flujo de autenticación

```
  Abrir app
      │
      ▼
  ¿Hay token guardado en EncryptedSharedPreferences?
      │
      ├── Sí ──▶ GET /me ──▶ ¿Válido? ──── Sí ──▶ Entra a Asistencia
      │                          │
      │                          └──── No ──▶ Borra token ──┐
      │                                                     │
      └── No ─────────────────────────────────────────────▶ Pantalla de Login
                                                                  │
                                          POST /login  ◀──────────┘
                                                │
                                    ¿Credenciales correctas?
                                                │
                            ┌───────── Sí ──────┴───── No ─────────┐
                            ▼                                     ▼
                Guarda token cifrado                    Mensaje de error
                Entra a Asistencia                      (no revela cuál campo falló)
```

### 2.2 Flujo del módulo de Asistencia

El sistema contempla **dos vías de registro**, porque en la práctica no siempre
es posible que el empleado marque desde la app (olvido, falla del teléfono,
personal sin cuenta).

```
   VÍA 1 — El empleado registra su propia asistencia
   ──────────────────────────────────────────────────
   Empleado abre la app
        │
        ▼
   ¿Su cuenta está vinculada a un empleado?  ── No ──▶ No se muestra el botón
        │
       Sí
        ▼
   Pulsa "Checar entrada"
        │
        ▼
   POST /asistencias/checar
        │
        ├─ ¿Ya checó hoy? ── Sí ──▶ HTTP 409 "Ya registraste tu entrada"
        │
        └─ No ──▶ Compara la hora contra el límite (09:00)
                       │
                       ├── ≤ 09:00 ──▶ estado = "presente"
                       └── > 09:00 ──▶ estado = "retardo"
                                │
                                ▼
                   Se guarda el registro y la lista se actualiza
                                │
                                ▼
                   Al terminar: "Checar salida" ──▶ POST /asistencias/checar-salida


   VÍA 2 — El administrador captura manualmente
   ─────────────────────────────────────────────
   Administrador pulsa "Captura manual"
        │
        ▼
   Selecciona empleado, fecha, estado y horas
        │
        ▼
   POST /asistencias  (origen = "admin")
        │
        ├─ ¿Ya existe registro de ese empleado en esa fecha? ── Sí ──▶ HTTP 409
        │
        └─ No ──▶ Se guarda y la lista se actualiza
```

### 2.3 Flujo del cálculo de nómina

```
   Usuario abre el módulo de Nómina
        │
        ▼
   Selecciona el periodo (por defecto, la última quincena)
        │
        ▼
   GET /nomina?inicio=YYYY-MM-DD&fin=YYYY-MM-DD
        │
        ▼
   Por cada empleado activo:
        │
        ├─ Cuenta los registros de asistencia del periodo
        │      • "presente" ──▶ cuenta como día trabajado
        │      • "retardo"  ──▶ cuenta como día trabajado (sí laboró)
        │      • "falta"    ──▶ NO cuenta
        │
        └─ total a pagar = días trabajados × salario diario
        │
        ▼
   Se devuelve el detalle por empleado + el total general
```

**Decisión de diseño:** la nómina **no se almacena**, se calcula al momento a
partir de la asistencia. Si se corrige un registro de asistencia, la nómina
refleja el cambio de inmediato; así se elimina el riesgo de tener dos versiones
distintas del mismo dato.

---

## 3. Secuencia de interacción con la aplicación

> *Insertar aquí las capturas en el orden indicado.*

| # | Captura | Qué demuestra |
|---|---|---|
| 1 | Pantalla de Login | Punto de entrada del sistema |
| 2 | Login con credenciales capturadas | Campo de contraseña oculto con opción de mostrar |
| 3 | Módulo de Asistencia | Pantalla principal tras autenticarse |
| 4 | Menú lateral desplegado | Navegación entre módulos y nombre real del usuario |
| 5 | "Mi asistencia de hoy" tras checar | Registro de entrada por el propio empleado (Vía 1) |
| 6 | Formulario de captura manual | Alta de asistencia por el administrador (Vía 2) |
| 7 | Lista actualizada con el nuevo registro | Confirmación de que el dato se guardó en la API |
| 8 | Módulo de Empleados | Listado consumido desde la API |
| 9 | Formulario de empleado | Alta/edición con validación de campos |
| 10 | Módulo de Nómina | Cálculo: días trabajados × salario diario |
| 11 | Error de red + botón Reintentar | Manejo de fallo de conexión (API apagada) |

---

## 4. Pruebas realizadas

### 4.1 Pruebas automatizadas (ejecutadas en el pipeline)

| Prueba | Herramienta | Resultado |
|---|---|---|
| Formato del código | `dart format --set-exit-if-changed` | Sin diferencias |
| Análisis estático | `flutter analyze` | *No issues found* |
| Prueba de widget | `flutter test` | *All tests passed* |
| Arranque de la API | `uvicorn` + `curl --fail` | Responde HTTP 200 |
| Compilación del APK | `flutter build apk --release` | APK generado (48.6 MB) |

### 4.2 Pruebas funcionales de la API

| Caso de prueba | Resultado esperado | Resultado obtenido |
|---|---|---|
| Consultar empleados sin token | Rechazo | **HTTP 403** |
| Consultar nómina sin token | Rechazo | **HTTP 403** |
| Login con contraseña incorrecta | Rechazo | **HTTP 401** |
| Login con credenciales válidas | Token emitido | **HTTP 200 + JWT** |
| Checar entrada dos veces el mismo día | Rechazo por duplicado | **HTTP 409** |
| Capturar asistencia duplicada (mismo empleado y fecha) | Rechazo | **HTTP 409** |
| Enviar un estado inválido | Rechazo por validación | **HTTP 400** |
| Token de una sesión anterior tras nuevo login | Rechazo | **HTTP 401** |
| Token tras cerrar sesión | Rechazo | **HTTP 401** |
| Cálculo de nómina del periodo | Total correcto | **72 días · $43,470.00** |

### 4.3 Pruebas de la imagen Docker

| Verificación | Resultado |
|---|---|
| Construcción de la imagen | Correcta — 282 MB |
| Usuario en ejecución | `uid=1000(appuser)` — **no root** |
| `HEALTHCHECK` del contenedor | Estado `healthy` |
| Seed automático en el primer arranque | Usuarios, empleados y asistencia cargados |
| Persistencia tras `docker restart` | Los datos permanecen |

### 4.4 Checklist de seguridad aplicado

| Requisito | Cómo se cumple |
|---|---|
| Tráfico HTTP bloqueado | `network_security_config.xml` con `cleartextTrafficPermitted="false"` |
| Sin credenciales en el código | `SECRET_KEY` por variable de entorno; credenciales en GitHub Secrets |
| Datos sensibles cifrados | Token en **EncryptedSharedPreferences** (`flutter_secure_storage`) |
| Contraseñas hasheadas | **bcrypt** con salt automático — nunca en texto plano |
| Permisos mínimos | Únicamente `android.permission.INTERNET` |

> **Nota sobre bcrypt:** se eligió bcrypt en lugar de SHA-256 porque SHA-256 es
> un hash rápido de propósito general, vulnerable a fuerza bruta con GPU. bcrypt
> está diseñado específicamente para contraseñas: incluye *salt* automático y un
> factor de costo que lo hace deliberadamente lento (recomendación de OWASP).

---

## 5. Pipeline CI/CD

**Ubicación:** `.github/workflows/ci.yml`

```
  push a develop ──┐                          push a main
                   │                               │
                   ▼                               ▼
        ┌──────────────────────────────────────────────────┐
        │  FASE CI  (ambas ramas, jobs en paralelo)        │
        │   Flutter: formato → analyze → test → APK        │
        │   API:     instalar → arrancar → responder       │
        └──────────────────────────────────────────────────┘
                   │                               │
        (develop termina aquí)                     ▼
                                    ┌──────────────────────────────┐
                                    │  FASE CD  (solo main)        │
                                    │   1. docker build            │
                                    │   2. push a docker.io        │
                                    │      (latest + SHA)          │
                                    │   3. deploy a staging        │
                                    │   4. APROBACIÓN MANUAL       │
                                    │   5. deploy a producción     │
                                    │      + GitHub Release (APK)  │
                                    └──────────────────────────────┘

        Cualquier fallo ⇒ notificación automática a Discord
```

**Aprobación manual antes de producción:** por tratarse de un sistema de nómina,
un despliegue defectuoso afecta el cálculo del pago de los empleados. Staging se
despliega de forma automática (retroalimentación rápida); producción exige
revisión humana mediante *required reviewers* de GitHub Environments.

### Ramas del repositorio

| Rama | Propósito |
|---|---|
| `main` | Código estable. Única rama que dispara la fase CD |
| `develop` | Integración del trabajo del equipo. Ejecuta la fase CI |
| `feature/<nombre>` | Rama individual por integrante; se integra a `develop` mediante *pull request* |

---

## 6. Documentos complementarios

| Documento | Contenido |
|---|---|
| `docs/P3_niveles_de_servicio.md` | Tabla SLI · SLO · SLA con justificación de cada valor |
| `docs/P3_dashboard_monitoreo.md` | Diseño del tablero de monitoreo (métricas, logs y trazas) |
| `docs/P3_plan_mejora_dora.md` | Las 4 métricas DORA medidas + 5 acciones de mejora |
| `TAREA_PIPELINE_CD.md` | Justificación de cada step del pipeline y del Dockerfile |

---

## 7. Anexo — Evidencias técnicas

> *Insertar aquí las capturas correspondientes.*

| # | Captura | Qué demuestra |
|---|---|---|
| A1 | Pestaña *Actions* con el pipeline en verde | El CI/CD se ejecuta correctamente |
| A2 | Artefactos descargables (`app-release-apk`, `coverage-report`) | El pipeline genera entregables |
| A3 | Instalación del APK en el dispositivo | La aplicación se distribuye e instala |
| A4 | Aplicación instalada en el menú de Android | Resultado final de la instalación |
| A5 | `docker build` completado | La imagen se construye correctamente |
| A6 | `docker ps` mostrando estado `healthy` | El contenedor opera con verificación de salud |
| A7 | Documentación Swagger (`/docs`) | La API está documentada automáticamente |
| A8 | `/publico/usuarios` mostrando hashes `$2b$12$...` | Las contraseñas están cifradas |
| A9 | Ramas del repositorio en GitHub | Flujo de trabajo con ramas |
| A10 | Notificación de fallo recibida en Discord | Alertas automáticas del pipeline |
