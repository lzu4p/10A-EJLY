import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/estado_vista.dart';

/// Módulo de Nómina.
///
/// El cálculo se hace en el servidor a partir de los registros de asistencia:
///     total a pagar = días trabajados x salario diario
/// Cuentan como día trabajado los estados "presente" y "retardo"; las faltas no.
class NominaScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const NominaScreen({super.key, required this.usuario});

  @override
  State<NominaScreen> createState() => _NominaScreenState();
}

class _NominaScreenState extends State<NominaScreen> {
  Map<String, dynamic>? _nomina;
  bool _cargando = true;
  String? _error;

  late DateTime _inicio;
  late DateTime _fin;

  @override
  void initState() {
    super.initState();
    // Periodo por defecto: la última quincena.
    _fin = DateTime.now();
    _inicio = _fin.subtract(const Duration(days: 14));
    _cargar();
  }

  String _fechaTexto(DateTime f) => '${f.year.toString().padLeft(4, '0')}-'
      '${f.month.toString().padLeft(2, '0')}-'
      '${f.day.toString().padLeft(2, '0')}';

  String _pesos(num v) {
    // Formato de miles: 43470.0 -> "43,470.00"
    final partes = v.toStringAsFixed(2).split('.');
    final entero = partes[0];
    final buffer = StringBuffer();
    for (int i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(entero[i]);
    }
    return '\$ $buffer.${partes[1]}';
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await ApiService.calcularNomina(
        inicio: _fechaTexto(_inicio),
        fin: _fechaTexto(_fin),
      );
      setState(() => _nomina = data);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _elegirPeriodo() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _inicio, end: _fin),
      helpText: 'Periodo de nómina',
    );
    if (rango != null) {
      setState(() {
        _inicio = rango.start;
        _fin = rango.end;
      });
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nómina'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Cambiar periodo',
            onPressed: _elegirPeriodo,
          ),
        ],
      ),
      drawer: AppDrawer(
        usuario: widget.usuario,
        pantallaActual: 'nomina',
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? VistaError(mensaje: _error!, onReintentar: _cargar)
              : _contenido(),
    );
  }

  Widget _contenido() {
    final n = _nomina!;
    final detalle = (n['detalle'] as List).cast<Map<String, dynamic>>();

    return Column(
      children: [
        _resumen(n),
        Expanded(
          child: detalle.isEmpty
              ? const VistaVacia(
                  icono: Icons.payments_outlined,
                  mensaje: 'Sin empleados en este periodo.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: detalle.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _tarjeta(detalle[i]),
                ),
        ),
      ],
    );
  }

  Widget _resumen(Map<String, dynamic> n) {
    final colores = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      color: colores.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.date_range, color: colores.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Periodo: ${n['periodo_inicio']} a ${n['periodo_fin']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colores.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _dato('Empleados', '${n['total_empleados']}', colores),
                _dato('Días pagados', '${n['total_dias_pagados']}', colores),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(
                    'TOTAL DE NÓMINA',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1,
                      color: colores.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    _pesos(n['total_nomina'] ?? 0),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colores.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(String etiqueta, String valor, ColorScheme colores) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colores.onPrimaryContainer,
          ),
        ),
        Text(
          etiqueta,
          style: TextStyle(fontSize: 12, color: colores.onPrimaryContainer),
        ),
      ],
    );
  }

  Widget _tarjeta(Map<String, dynamic> d) {
    final colores = Theme.of(context).colorScheme;
    final faltas = d['dias_falta'] ?? 0;
    final retardos = d['dias_retardo'] ?? 0;

    return Card(
      elevation: 0,
      color: colores.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${d['empleado_nombre']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                Text(
                  _pesos(d['total_pagar'] ?? 0),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: colores.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${d['puesto']} · ${d['departamento']}',
              style: TextStyle(fontSize: 12, color: colores.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            // Se muestra la fórmula aplicada, para que el cálculo sea auditable.
            Text(
              '${d['dias_trabajados']} días × ${_pesos(d['salario_diario'] ?? 0)}',
              style: TextStyle(fontSize: 13, color: colores.onSurfaceVariant),
            ),
            if (retardos > 0 || faltas > 0) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  if (retardos > 0)
                    _etiqueta('$retardos retardos', Colors.orange),
                  if (faltas > 0) _etiqueta('$faltas faltas', Colors.red),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
