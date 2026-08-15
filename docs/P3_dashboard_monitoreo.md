# Diseño del Dashboard de Monitoreo

**Sistema:** Control de Asistencia y Nómina
**Nota:** este documento es el **diseño** del tablero (maqueta + especificación de
cada panel). El diagrama puede redibujarse en draw.io a partir del esquema de abajo.

---

## Los tres pilares de la observabilidad

El tablero se organiza según los tres tipos de señal que permiten entender un sistema:

| Pilar | Responde a la pregunta | En nuestro sistema |
|---|---|---|
| **Métricas** | ¿*Qué* está pasando? | Disponibilidad, latencia, tasa de errores, peticiones por minuto |
| **Logs** | ¿*Por qué* está pasando? | Registros de uvicorn, errores de la API, intentos de login |
| **Trazas** | ¿*Dónde* está pasando? | Recorrido de una petición: app → API → base de datos |

---

## Maqueta del tablero

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  SISTEMA DE ASISTENCIA Y NÓMINA — Monitoreo        [ 24 h ▾ ]  ● en vivo      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  FILA 1 — ESTADO GENERAL (semáforo: verde / ámbar / rojo)                     │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ │
│  │ DISPONIBILIDAD │ │  LATENCIA p95  │ │ TASA DE ERROR  │ │ ERROR BUDGET   │ │
│  │                │ │                │ │                │ │                │ │
│  │     99.4 %     │ │     420 ms     │ │     0.3 %      │ │   68 % libre   │ │
│  │  SLO: ≥ 99 %   │ │  SLO: < 800 ms │ │  SLO: < 1 %    │ │  293 min resta │ │
│  │      ▲ verde   │ │      ▲ verde   │ │      ▲ verde   │ │     ▲ verde    │ │
│  └────────────────┘ └────────────────┘ └────────────────┘ └────────────────┘ │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  FILA 2 — MÉTRICAS EN EL TIEMPO                                              │
│  ┌───────────────────────────────────┐ ┌──────────────────────────────────┐  │
│  │ Peticiones por minuto             │ │ Latencia p50 / p95 / p99         │  │
│  │      ╭╮      ╭─╮                  │ │  p99 ┈┈┈┈┈╱╲┈┈┈┈┈┈┈┈┈┈┈┈┈       │  │
│  │   ╭──╯╰──╮╭──╯ ╰──╮               │ │  p95 ─────╯  ╲──────────────     │  │
│  │ ──╯      ╰╯       ╰────           │ │  p50 ════════════════════════    │  │
│  │  8h    12h    16h    20h          │ │  ── umbral SLO 800 ms ──         │  │
│  └───────────────────────────────────┘ └──────────────────────────────────┘  │
│                                                                              │
│  ┌───────────────────────────────────┐ ┌──────────────────────────────────┐  │
│  │ Respuestas por código             │ │ Logins: éxito vs. fallo          │  │
│  │  2xx ████████████████████  94 %   │ │  éxito  ██████████████████ 91 %  │  │
│  │  4xx ███                    5 %   │ │  fallo  ███                 9 %  │  │
│  │  5xx ▎                      0.3 % │ │  (picos de fallo = posible       │  │
│  │                                   │ │   ataque de fuerza bruta)        │  │
│  └───────────────────────────────────┘ └──────────────────────────────────┘  │
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  FILA 3 — LOGS  (filtro: [ solo errores ▾ ] [ buscar… ] )                     │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │ 14:32:07  INFO   POST /login       200  usuario=izu           88 ms      ││
│  │ 14:32:19  INFO   GET  /productos   200  registros=3           41 ms      ││
│  │ 14:33:02  WARN   POST /login       401  usuario=desconocido   35 ms      ││
│  │ 14:35:44  ERROR  PUT  /usuarios/2  500  IntegrityError       120 ms      ││
│  │ 14:35:45  INFO   HEALTHCHECK       200  contenedor healthy     12 ms     ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  FILA 4 — TRAZA DE UNA PETICIÓN (se abre al hacer clic en un log)             │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │  POST /login — traza completa: 88 ms                                     ││
│  │                                                                          ││
│  │  App Flutter  ├──┤ 6 ms      envío de la petición                        ││
│  │  Red          ├────┤ 14 ms   latencia de red                             ││
│  │  API FastAPI  ├──┤ 5 ms      validación del cuerpo                       ││
│  │  SQLite       ├───┤ 9 ms     SELECT del usuario                          ││
│  │  bcrypt       ├──────────────────┤ 48 ms  verificación de contraseña ◀── ││
│  │  JWT          ├──┤ 4 ms      firma del token                             ││
│  │  Respuesta    ├─┤ 2 ms                                                   ││
│  │                                                                          ││
│  │  ◀── bcrypt concentra el 55 % del tiempo. Es ESPERADO Y DESEABLE:        ││
│  │      su lentitud es la defensa contra ataques de fuerza bruta.           ││
│  └──────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│  FILA 5 — ESTADO DEL PIPELINE CI/CD                                          │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │  Último despliegue: v1.0.42  ·  hace 2 h  ·  por: lzu4p  ·  ✓ éxito      ││
│  │  CI ✓ ── Docker ✓ ── Staging ✓ ── Producción ✓ (aprobado por el líder)   ││
│  │  Frecuencia de despliegue: 3 esta semana  ·  Fallos de cambio: 0         ││
│  └──────────────────────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## Especificación de cada panel

### Fila 1 — Estado general

| Panel | Métrica | Umbrales del semáforo | Por qué está en la primera fila |
|---|---|---|---|
| Disponibilidad | % de respuestas sin 5xx | Verde ≥ 99 % · Ámbar 95–99 % · Rojo < 95 % | Es el indicador que resume "¿el sistema sirve?" |
| Latencia p95 | Percentil 95 del tiempo de respuesta | Verde < 800 ms · Ámbar 0.8–2 s · Rojo > 2 s | Se usa p95 y no promedio: el promedio oculta los casos lentos |
| Tasa de error | % de respuestas 5xx | Verde < 1 % · Ámbar 1–5 % · Rojo > 5 % | Distingue "encendido" de "funcionando bien" |
| Error budget | Minutos de caída restantes en el mes | Verde > 50 % · Ámbar 20–50 % · Rojo < 20 % | Regla objetiva para decidir entre nuevas funciones o estabilidad |

> **Criterio de diseño:** los cuatro paneles superiores responden en cinco segundos
> a "¿hay algo mal ahora?". El detalle vive más abajo. Un tablero que obliga a
> interpretar diez gráficas antes de saber si hay un problema no cumple su función.

### Fila 2 — Métricas en el tiempo

- **Peticiones por minuto:** revela patrones de uso (picos en horario de entrada y
  salida del personal) y caídas de tráfico que pueden indicar que la app no conecta.
- **Latencia p50/p95/p99:** tres percentiles juntos muestran si la lentitud afecta a
  todos (las tres líneas suben) o solo a una minoría (solo p99 sube).
- **Respuestas por código:** separa fallos del servidor (5xx, culpa nuestra) de
  errores del cliente (4xx, petición mal formada o credenciales incorrectas).
- **Logins éxito/fallo:** un aumento repentino de fallos puede indicar un ataque de
  fuerza bruta; es un panel de seguridad, no solo de rendimiento.

### Fila 3 — Logs

Registro estructurado con marca de tiempo, nivel, método, ruta, código y duración.
Filtrable por nivel y con búsqueda de texto.

**Regla de privacidad:** los logs **nunca** registran contraseñas ni tokens completos.
En el ejemplo se ve `usuario=izu`, jamás su contraseña. Esto es coherente con el
checklist de seguridad: un log filtrado no debe convertirse en una fuga de credenciales.

### Fila 4 — Trazas

Descompone una petición en sus etapas para localizar **dónde** se va el tiempo. El
ejemplo del login es didáctico: bcrypt consume más de la mitad, y eso es correcto por
diseño — su lentitud deliberada es lo que protege contra ataques de fuerza bruta.
Sin la traza, alguien podría "optimizar" ese paso y debilitar la seguridad.

### Fila 5 — Estado del pipeline

Conecta el monitoreo con la entrega: permite correlacionar un despliegue reciente con
una degradación del servicio. Si la latencia se disparó justo después de la versión
v1.0.42, el culpable es evidente.

---

## Alertas propuestas

| Condición | Severidad | Canal | Justificación |
|---|---|---|---|
| Disponibilidad < 95 % en 5 min | Crítica | Discord (mención al equipo) | Incumple el SLA: exige acción inmediata |
| Latencia p95 > 2 s por 10 min | Alta | Discord | Degradación sostenida, no un pico aislado |
| Cualquier respuesta 5xx | Media | Discord | Volumen bajo: cada error del servidor merece revisión |
| Contenedor no *healthy* | Crítica | Discord | El servicio está caído |
| Pipeline CI/CD fallido | Alta | Discord | **Ya implementado** en `notify-on-failure` |
| > 10 logins fallidos del mismo usuario en 1 min | Alta (seguridad) | Discord | Patrón de fuerza bruta |

> **Criterio anti-fatiga:** las alertas exigen ventanas de tiempo (5–10 min) en lugar
> de dispararse ante el primer dato anómalo. Un equipo que recibe alertas falsas
> constantemente termina ignorándolas, y entonces la alerta real pasa desapercibida.

---

## Herramientas propuestas para implementarlo

| Capa | Herramienta | Motivo |
|---|---|---|
| Métricas | Prometheus | Estándar de la industria, gratuito, se integra con FastAPI mediante `prometheus-fastapi-instrumentator` |
| Visualización | Grafana | Construye este tablero sobre Prometheus; corre en contenedor junto a la API |
| Logs | Loki | Del mismo ecosistema que Grafana; evita montar un stack ELK, demasiado pesado para una Raspberry Pi |
| Trazas | OpenTelemetry | Estándar abierto, sin dependencia de un proveedor |
| Alertas | Alertmanager → webhook de Discord | **Reutiliza el webhook que el pipeline ya usa** |

**Estado actual:** el sistema ya cuenta con dos señales en funcionamiento — el
`HEALTHCHECK` del contenedor y la notificación de fallos del pipeline a Discord. El
resto del tablero es el diseño objetivo, cuya implementación forma parte del plan de mejora.
