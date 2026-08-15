# Niveles de Servicio — SLI · SLO · SLA

**Sistema:** Control de Asistencia y Nómina
**Equipo:** Jose Armando Sanchez Patricio · Luis Alfredo Ramirez Huerta · Yohan Arturo Escobedo Sandoval

---

## Conceptos aplicados a este sistema

| Término | Qué es | Ejemplo en nuestro sistema |
|---|---|---|
| **SLI** (*Service Level Indicator*) | La **métrica** que se mide | Porcentaje de peticiones a la API que responden sin error |
| **SLO** (*Service Level Objective*) | La **meta interna** del equipo | Ese porcentaje debe ser ≥ 99 % al mes |
| **SLA** (*Service Level Agreement*) | El **compromiso formal** con el cliente, con consecuencias si se incumple | Se garantiza ≥ 95 %; por debajo, se reporta al área de RH y se levanta un plan de corrección |

**Por qué el SLA siempre es más laxo que el SLO:** el SLO es la meta que el equipo
se exige internamente; el SLA es lo que se promete por fuera. Dejar un margen entre
ambos permite detectar y corregir la degradación *antes* de incumplir el compromiso.

---

## Tabla de niveles de servicio

| # | SLI (qué se mide) | Cómo se mide | SLO (meta interna) | SLA (compromiso) | Justificación del valor |
|---|---|---|---|---|---|
| 1 | **Disponibilidad de la API** | % de respuestas con código distinto de 5xx sobre el total, ventana de 30 días | **99.0 %** | **95.0 %** | 99 % permite ~7 h de caída al mes. Es realista para un equipo de 3 estudiantes con la API en una Raspberry Pi doméstica sin redundancia ni energía respaldada. Prometer 99.9 % (43 min/mes) sería incumplible y por tanto deshonesto. |
| 2 | **Latencia de consulta** | Percentil 95 del tiempo de respuesta en `GET /empleados` y `GET /asistencias` | **< 800 ms** | **< 2 s** | Se usa el **percentil 95 y no el promedio** porque el promedio esconde los casos malos: si 5 de 100 peticiones tardan 10 s, el promedio sigue viéndose bien. La app es móvil y puede operar por red celular; 800 ms mantiene la interfaz fluida sin exigir infraestructura costosa. |
| 3 | **Éxito de autenticación** | % de peticiones a `POST /login` que responden 200 o 401 (es decir, que *no* fallan por error del servidor) | **99.5 %** | **98.0 %** | Es más estricto que la disponibilidad general porque el login es la **puerta de entrada**: si falla, el usuario no puede hacer absolutamente nada. Un 401 por contraseña incorrecta **no** cuenta como falla: el sistema funcionó correctamente al rechazar. |
| 4 | **Tasa de errores del CRUD** | % de peticiones 5xx en los endpoints de empleados, asistencia y nomina | **< 1.0 %** | **< 5.0 %** | Complementa la disponibilidad midiendo la corrección funcional, no solo que el servidor esté encendido. Un 1 % en el volumen esperado (decenas de operaciones diarias) equivale a menos de una falla al día. |
| 5 | **Integridad de los datos de nómina** | Nº de registros perdidos o corruptos por mes | **0** | **0** | **Único indicador con tolerancia cero.** Se trata del cálculo del pago de empleados: un solo registro perdido significa que alguien cobra mal. No admite margen. Se sostiene con el volumen Docker persistente y el respaldo de la base. |
| 6 | **Tiempo de recuperación (MTTR)** | Minutos entre la detección de la falla y el servicio restablecido | **< 30 min** | **< 4 h** | El pipeline permite volver a la imagen anterior por su etiqueta SHA con un solo comando, y la alerta llega automáticamente a Discord. 30 minutos contempla que el equipo no está de guardia 24/7: es una meta honesta para un proyecto académico. |

---

## Cómo se obtienen estas métricas hoy

| SLI | Fuente actual | Fuente ideal (mejora futura) |
|---|---|---|
| Disponibilidad | `HEALTHCHECK` del contenedor Docker (cada 30 s) | Prometheus + *blackbox exporter* |
| Latencia | Logs de acceso de uvicorn | Middleware de métricas en FastAPI + Prometheus |
| Éxito de login | Logs de la API filtrados por endpoint | Contador dedicado por código de respuesta |
| Errores CRUD | Logs de la API (códigos 5xx) | Alerta automática al superar el umbral |
| Integridad | Conteo de registros en SQLite | Verificación periódica del respaldo |
| MTTR | Registro manual de incidentes | Marcas de tiempo automáticas del pipeline |

**Reconocimiento honesto:** actualmente la medición es en su mayoría manual, a
partir de los logs del contenedor. El propio `HEALTHCHECK` ya es un SLI automático
en funcionamiento. Instrumentar el resto es una de las acciones del plan de mejora.

---

## Presupuesto de error (*error budget*)

Con un SLO de disponibilidad del **99 %** en 30 días, el margen tolerable de caída es:

```
30 días × 24 h × 60 min = 43 200 minutos
1 % de 43 200            = 432 minutos ≈ 7.2 horas al mes
```

**Cómo se usa este presupuesto:** mientras quede margen disponible, el equipo puede
desplegar cambios con normalidad. Si un mes se consume por completo, se congelan las
funciones nuevas y el siguiente sprint se dedica a estabilidad. Es una regla objetiva
para decidir entre "avanzar" y "corregir", en lugar de discutirlo por intuición.
