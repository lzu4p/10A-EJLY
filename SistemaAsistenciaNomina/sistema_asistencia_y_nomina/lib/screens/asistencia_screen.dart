import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/estado_vista.dart';
import 'asistencia_form_screen.dart';

/// Módulo de Asistencia.
///
/// Contempla las dos formas de registro del sistema:
///  - El propio empleado marca su entrada y salida (tarjeta superior).
///  - El administrador captura manualmente (botón flotante).
class AsistenciaScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const AsistenciaScreen({super.key, required this.usuario});

  @override
  State<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends State<AsistenciaScreen> {
  List<Map<String, dynamic>> _registros = [];
  Map<String, dynamic>? _miAsistencia;
  bool _cargando = true;
  bool _procesandoChecada = false;
  String? _error;
  DateTime _fecha = DateTime.now();

  /// Solo las cuentas vinculadas a un empleado pueden checar.
  bool get _puedeChecar => widget.usuario['empleado_id'] != null;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  String _fechaTexto(DateTime f) => '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';

  bool get _esHoy {
    final hoy = DateTime.now();
    return _fecha.year == hoy.year &&
        _fecha.month == hoy.month &&
        _fecha.day == hoy.day;
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final registros =
          await ApiService.fetchAsistencias(fecha: _fechaTexto(_fecha));
      Map<String, dynamic>? mia;
      if (_puedeChecar) {
        mia = await ApiService.miAsistenciaDeHoy();
      }
      setState(() {
        _registros = registros;
        _miAsistencia = mia;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _checar({required bool entrada}) async {
    setState(() => _procesandoChecada = true);
    try {
      final mensaje = entrada
          ? await ApiService.checarEntrada()
          : await ApiService.checarSalida();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$e'.replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _procesandoChecada = false);
      }
    }
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Ver asistencia del día',
    );
    if (elegida != null) {
      setState(() => _fecha = elegida);
      _cargar();
    }
  }

  Future<void> _capturaManual() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AsistenciaFormScreen(fechaInicial: _fecha),
      ),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Cambiar fecha',
            onPressed: _elegirFecha,
          ),
        ],
      ),
      drawer: AppDrawer(
        usuario: widget.usuario,
        pantallaActual: 'asistencia',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _capturaManual,
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Captura manual'),
      ),
      body: Column(
        children: [
          if (_puedeChecar) _tarjetaChecada(),
          _encabezadoFecha(),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? VistaError(mensaje: _error!, onReintentar: _cargar)
                    : _registros.isEmpty
                        ? const VistaVacia(
                            icono: Icons.event_busy_outlined,
                            mensaje: 'Sin registros de asistencia este día.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                            itemCount: _registros.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) =>
                                _tarjetaRegistro(_registros[i]),
                          ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta para que el usuario registre su propia entrada y salida.
  Widget _tarjetaChecada() {
    final colores = Theme.of(context).colorScheme;
    final entrada = _miAsistencia?['hora_entrada'];
    final salida = _miAsistencia?['hora_salida'];

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      color: colores.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.how_to_reg, color: colores.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Mi asistencia de hoy',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colores.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entrada == null
                  ? 'Aún no has registrado tu entrada.'
                  : 'Entrada: $entrada'
                      '${salida != null ? '   ·   Salida: $salida' : ''}',
              style: TextStyle(color: colores.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_procesandoChecada || entrada != null)
                        ? null
                        : () => _checar(entrada: true),
                    icon: const Icon(Icons.login),
                    label: const Text('Checar entrada'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: (_procesandoChecada ||
                            entrada == null ||
                            salida != null)
                        ? null
                        : () => _checar(entrada: false),
                    icon: const Icon(Icons.logout),
                    label: const Text('Checar salida'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezadoFecha() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.event, size: 20),
          const SizedBox(width: 8),
          Text(
            _esHoy ? 'Hoy · ${_fechaTexto(_fecha)}' : _fechaTexto(_fecha),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text('${_registros.length} registros'),
        ],
      ),
    );
  }

  Widget _tarjetaRegistro(Map<String, dynamic> r) {
    final estado = '${r['estado'] ?? ''}';
    final colorEstado = switch (estado) {
      'presente' => Colors.green,
      'retardo' => Colors.orange,
      _ => Colors.red,
    };

    return Card(
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
      child: ListTile(
        leading: Icon(Icons.circle, size: 14, color: colorEstado),
        title: Text(
          '${r['empleado_nombre'] ?? 'Empleado ${r['empleado_id']}'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          estado == 'falta'
              ? 'Falta'
              : 'Entrada: ${r['hora_entrada'] ?? '--:--'}'
                  '   ·   Salida: ${r['hora_salida'] ?? '--:--'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorEstado.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                estado,
                style: TextStyle(
                  color: colorEstado,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${r['origen'] ?? ''}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
