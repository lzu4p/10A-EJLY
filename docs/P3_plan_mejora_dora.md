# Plan de Mejora — Métricas DORA

**Sistema:** Control de Asistencia y Nómina
**Periodo analizado:** 9 de junio – 14 de agosto de 2026 (≈ 9.4 semanas)
**Datos de origen:** historial real del repositorio `lzu4p/10A-EJLY` (22 commits, 3 merges a `main`)

---

## Qué son las métricas DORA

Las cuatro métricas del programa *DevOps Research and Assessment* (Google) miden el
desempeño de un equipo de entrega de software. Se dividen en dos parejas:

| Pareja | Métricas | Qué mide |
|---|---|---|
| **Velocidad** | Frecuencia de despliegue · Tiempo de entrega | Qué tan rápido entrega valor el equipo |
| **Estabilidad** | Tasa de fallo de cambios · Tiempo de restauración | Qué tan confiable es lo que entrega |

**Por qué se miden juntas:** medir solo velocidad incentiva desplegar rápido y romper
cosas; medir solo estabilidad incentiva no desplegar nunca. El buen desempeño consiste
en mejorar ambas **a la vez**, y los datos de DORA muestran que no son contradictorias.

---

## Las 4 métricas aplicadas a nuestro sistema

### 1. Frecuencia de Despliegue (*Deployment Frequency*)

| Concepto | Valor |
|---|---|
| **Definición** | Cada cuánto llega código a producción |
| **Nuestra medición** | 3 merges a `main` en 9.4 semanas = **1 despliegue cada ~3 semanas** |
| **Nivel DORA** | **Medio** (entre una vez por semana y una vez al mes) |
| **Meta propuesta** | 1 despliegue por semana (nivel **Alto**) |

**Análisis:** la baja frecuencia no se debe a impedimentos técnicos, sino al ritmo
académico: el trabajo se concentra antes de cada entrega parcial. Los datos lo
confirman — hay 8 commits en un solo día (14 de agosto) y semanas enteras sin actividad.
Desplegar en lotes grandes y espaciados **aumenta el riesgo**: si algo falla, hay
muchos cambios entre los cuales buscar la causa.

---

### 2. Tiempo de Entrega de Cambios (*Lead Time for Changes*)

| Concepto | Valor |
|---|---|
| **Definición** | Tiempo desde que se hace *commit* hasta que ese código corre en producción |
| **Nuestra medición** | ≈ **5–20 días** (el trabajo se acumula en la rama hasta el merge de la entrega) |
| **Nivel DORA** | **Medio** (entre una semana y un mes) |
| **Meta propuesta** | < 1 día para llegar a staging (nivel **Alto**) |

**Análisis:** el pipeline en sí es rápido — el CI completo tarda minutos. El cuello de
botella es **humano**: el código terminado espera días hasta que alguien decide hacer
el merge. Automatizar el paso de `develop` a staging elimina esa espera sin sacrificar
el control sobre producción.

---

### 3. Tasa de Fallo de Cambios (*Change Failure Rate*)

| Concepto | Valor |
|---|---|
| **Definición** | % de despliegues que provocan una falla en producción y requieren corrección |
| **Nuestra medición** | **0 %** en producción — pero **~30 % de las ejecuciones del CI fallaron** |
| **Nivel DORA** | **Elite** en producción (0 %), aunque el dato requiere el matiz de abajo |
| **Meta propuesta** | Mantener < 15 % y **reducir los fallos del CI a la mitad** |

**Matiz honesto e importante:** el 0 % en producción no significa que el equipo no
cometa errores; significa que **el pipeline los detuvo antes**. Durante el desarrollo
se registraron fallos reales:

| Incidente | Dónde se detectó | Consecuencia |
|---|---|---|
| Versión de Gradle incompatible (8.5 < 8.7) | Compilación local | Bloqueó el build |
| Android Gradle Plugin desactualizado (8.1 < 8.6) | Compilación local | Bloqueó el build |
| Código sin formatear según `dart format` | **CI (GitHub Actions)** | Detuvo el pipeline |
| Test obsoleto referenciando la clase `MyApp` | **CI (GitHub Actions)** | Detuvo el pipeline |
| Permisos incorrectos en el `Dockerfile` (SQLite no podía crear la BD) | Prueba local del contenedor | Se corrigió antes de publicar |

**Interpretación:** cada uno de esos fallos habría sido un incidente en producción si
no existiera el pipeline. **Esa es exactamente la función del CI**: convertir fallos
caros (en producción) en fallos baratos (en el runner). El 0 % de fallo en producción
es un resultado del proceso, no una casualidad.

---

### 4. Tiempo Medio de Restauración (*MTTR*)

| Concepto | Valor |
|---|---|
| **Definición** | Cuánto se tarda en restablecer el servicio tras una falla |
| **Nuestra medición** | **< 1 hora** en los incidentes registrados (todos en desarrollo) |
| **Nivel DORA** | **Alto** (menos de un día) |
| **Meta propuesta** | < 30 min con reversión automatizada |

**Análisis:** el sistema ya cuenta con dos elementos que favorecen un MTTR bajo:

1. **Imágenes etiquetadas por SHA de commit** — revertir es un único comando:
   `docker run ...api:<sha-anterior>`, sin necesidad de recompilar.
2. **Alerta automática a Discord** ante un pipeline fallido — el equipo se entera sin
   tener que revisar GitHub manualmente.

La debilidad es que la reversión es **manual**: alguien debe darse cuenta, conectarse
al servidor y ejecutar el comando.

---

## Tabla resumen

| Métrica | Valor actual | Nivel DORA | Meta | Prioridad |
|---|---|---|---|---|
| Frecuencia de despliegue | 1 cada 3 semanas | Medio | 1 por semana | **Alta** |
| Tiempo de entrega | 5–20 días | Medio | < 1 día a staging | **Alta** |
| Tasa de fallo de cambios | 0 % prod / 30 % CI | Elite (prod) | < 15 %, menos fallos de CI | Media |
| Tiempo de restauración | < 1 hora | Alto | < 30 min | Media |

**Lectura del conjunto:** el equipo es **estable pero lento**. Las dos métricas de
estabilidad están en buen nivel; las dos de velocidad se quedan en el nivel medio.
Por eso las acciones de mejora priorizan la velocidad — sin sacrificar la estabilidad
ya conseguida.

---

## Acciones de mejora

### Acción 1 — Desplegar `develop` a staging automáticamente *(prioridad alta)*

**Situación actual:** solo `main` dispara la fase CD. El código en `develop` se valida
(pruebas y análisis), pero nadie puede *usarlo* hasta el merge a `main`.

**Propuesta:** que cada push a `develop` construya y despliegue automáticamente en
staging, mientras producción conserva la aprobación manual.

**Métricas que mejora:**
- *Frecuencia de despliegue:* de 1 cada 3 semanas a varios por semana en staging.
- *Tiempo de entrega:* de 5–20 días a **minutos** para llegar a un entorno usable.

**Por qué no compromete la estabilidad:** staging **no** es producción. El riesgo de
un despliegue fallido ahí es que el equipo encuentre un error — que es precisamente el
objetivo. La barrera de aprobación humana permanece intacta donde importa: producción.

**Implementación:** ajustar la condición de rama del job de staging para aceptar
también `develop`, usando etiquetas de imagen diferenciadas por entorno.

---

### Acción 2 — Ampliar la cobertura de pruebas automatizadas *(prioridad alta)*

**Situación actual:** el proyecto tiene **1 solo test** (`widget_test.dart`, que
verifica que la app arranca) y una prueba de humo de la API. Toda la lógica de
negocio —validación de credenciales, expiración del token, hasheado de contraseñas,
manejo de errores de red— se prueba **manualmente**.

**Propuesta:** añadir pruebas automatizadas en tres frentes:

| Frente | Pruebas concretas | Herramienta |
|---|---|---|
| API — autenticación | Login correcto, contraseña incorrecta, token expirado, token inválido, logout invalida el token | `pytest` + `TestClient` de FastAPI |
| API — CRUD | Crear/editar producto, usuario duplicado devuelve 409, acceso sin token devuelve 403 | `pytest` |
| App — widgets | El formulario valida campos vacíos, el botón de mostrar/ocultar contraseña funciona, la tabla se llena con datos simulados | `flutter_test` + `mockito` |

**Métricas que mejora:**
- *Tasa de fallo de cambios:* cada prueba nueva es un error que ya no llegará a producción.
- *Tiempo de entrega:* con buena cobertura, el equipo despliega **con confianza** en lugar de dedicar días a verificar a mano.

**Evidencia que respalda esta acción:** el incidente del test obsoleto (`MyApp`) fue
detectado por el CI, no por una persona. Con más pruebas, más errores se detectan solos.

---

### Acción 3 — Reversión automática ante fallo del despliegue *(prioridad media)*

**Situación actual:** si la prueba de humo posterior al despliegue falla, el pipeline
se marca en rojo y avisa por Discord — pero **el servicio queda caído** hasta que
alguien intervenga manualmente.

**Propuesta:** que el propio job, al detectar que la prueba de humo falla, vuelva a
levantar automáticamente la imagen de la versión anterior (recuperable por su etiqueta SHA).

**Métrica que mejora:**
- *Tiempo de restauración:* de "< 1 hora, dependiente de que alguien esté disponible"
  a **segundos**, sin intervención humana.

**Por qué es viable:** toda la infraestructura necesaria ya existe. Las imágenes están
etiquetadas por SHA, así que la versión anterior siempre está disponible en el registro.
Solo falta la lógica condicional en el pipeline.

---

### Acción 4 — Instrumentar métricas reales *(prioridad media)*

**Situación actual:** los SLI definidos en el documento de niveles de servicio se
miden manualmente leyendo los logs del contenedor. Solo el `HEALTHCHECK` es automático.

**Propuesta:** añadir `prometheus-fastapi-instrumentator` a la API (una línea de
configuración) y desplegar Prometheus junto a Grafana en el mismo servidor.

**Métricas que mejora:**
- *Tiempo de restauración:* detectar la degradación en minutos en lugar de esperar a
  que un usuario reporte el problema.
- Habilita medir con datos los SLO que hoy solo están definidos en papel.

**Dependencia:** es requisito para implementar el dashboard diseñado en el documento
de monitoreo.

---

## Conclusión

El equipo presenta un perfil **estable pero lento**: el pipeline detiene los errores
de forma efectiva (0 % de fallo en producción, MTTR bajo), pero el ritmo de entrega
está limitado por pasos manuales y por el calendario académico.

Las dos acciones prioritarias —despliegue automático a staging y ampliación de las
pruebas— atacan directamente las dos métricas más débiles, y ninguna de las dos
requiere infraestructura adicional: se implementan sobre el pipeline que ya existe.
