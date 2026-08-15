import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Captura manual de asistencia hecha por el administrador.
/// Cubre el caso en que el empleado no pudo checar desde la app.
class AsistenciaFormScreen extends StatefulWidget {
  final DateTime fechaInicial;

  const AsistenciaFormScreen({super.key, required this.fechaInicial});

  @override
  State<AsistenciaFormScreen> createState() => _AsistenciaFormScreenState();
}

class _AsistenciaFormScreenState extends State<AsistenciaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _empleados = [];
  int? _empleadoId;
  late DateTime _fecha;
  String _estado = 'presente';
  TimeOfDay? _entrada;
  TimeOfDay? _salida;

  bool _cargandoEmpleados = true;
  bool _guardando = false;
  String? _errorCarga;

  static const _estados = ['presente', 'retardo', 'falta'];

  @override
  void initState() {
    super.initState();
    _fecha = widget.fechaInicial;
    _cargarEmpleados();
  }

  Future<void> _cargarEmpleados() async {
    setState(() {
      _cargandoEmpleados = true;
      _errorCarga = null;
    });
    try {
      final data = await ApiService.fetchEmpleados();
      setState(() {
        // Solo empleados activos pueden recibir registros nuevos.
        _empleados = data.where((e) => e['activo'] == 1).toList();
      });
    } catch (e) {
      setState(() => _errorCarga = '$e');
    } finally {
      if (mounted) {
        setState(() => _cargandoEmpleados = false);
      }
    }
  }

  String _fechaTexto() => '${_fecha.year.toString().padLeft(4, '0')}-'
      '${_fecha.month.toString().padLeft(2, '0')}-'
      '${_fecha.day.toString().padLeft(2, '0')}';

  String? _horaTexto(TimeOfDay? h) => h == null
      ? null
      : '${h.hour.toString().padLeft(2, '0')}:'
          '${h.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (elegida != null) {
      setState(() => _fecha = elegida);
    }
  }

  Future<void> _elegirHora({required bool entrada}) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: entrada
          ? (_entrada ?? const TimeOfDay(hour: 8, minute: 30))
          : (_salida ?? const TimeOfDay(hour: 17, minute: 0)),
    );
    if (elegida != null) {
      setState(() {
        if (entrada) {
          _entrada = elegida;
        } else {
          _salida = elegida;
        }
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_empleadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un empleado')),
      );
      return;
    }

    setState(() => _guardando = true);

    // En una falta no se registran horas.
    final esFalta = _estado == 'falta';
    final datos = <String, dynamic>{
      'empleado_id': _empleadoId,
      'fecha': _fechaTexto(),
      'estado': _estado,
      'hora_entrada': esFalta ? null : _horaTexto(_entrada),
      'hora_salida': esFalta ? null : _horaTexto(_salida),
    };

    try {
      await ApiService.capturarAsistencia(datos);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
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
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Captura manual'),
        centerTitle: true,
      ),
      body: _cargandoEmpleados
          ? const Center(child: CircularProgressIndicator())
          : _errorCarga != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _errorCarga!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _cargarEmpleados,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _formulario(),
    );
  }

  Widget _formulario() {
    final esFalta = _estado == 'falta';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _empleadoId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Empleado',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: _empleados
                  .map((e) => DropdownMenuItem<int>(
                        value: e['id'] as int,
                        child: Text(
                          '${e['nombre']} · ${e['puesto']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _empleadoId = v),
              validator: (v) => v == null ? 'Selecciona un empleado' : null,
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: _elegirFecha,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text('Fecha: ${_fechaTexto()}'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _estado,
              decoration: const InputDecoration(
                labelText: 'Estado',
                prefixIcon: Icon(Icons.flag_outlined),
                border: OutlineInputBorder(),
              ),
              items: _estados
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s[0].toUpperCase() + s.substring(1)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _estado = v ?? 'presente'),
            ),
            const SizedBox(height: 16),

            // Las horas solo aplican si el empleado sí se presentó.
            if (!esFalta) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _elegirHora(entrada: true),
                      icon: const Icon(Icons.login, size: 18),
                      label: Text(_entrada == null
                          ? 'Entrada'
                          : 'Entrada ${_horaTexto(_entrada)}'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _elegirHora(entrada: false),
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(_salida == null
                          ? 'Salida'
                          : 'Salida ${_horaTexto(_salida)}'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Una falta no registra horas y no se paga en la nómina.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text(
                  'Registrar asistencia',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
