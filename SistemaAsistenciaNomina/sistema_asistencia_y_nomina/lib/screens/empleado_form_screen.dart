import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

/// Alta y edición de un empleado.
/// Si `empleado` es null se trata de un alta; si no, de una edición.
class EmpleadoFormScreen extends StatefulWidget {
  final Map<String, dynamic>? empleado;

  const EmpleadoFormScreen({super.key, this.empleado});

  @override
  State<EmpleadoFormScreen> createState() => _EmpleadoFormScreenState();
}

class _EmpleadoFormScreenState extends State<EmpleadoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _puestoCtrl = TextEditingController();
  final _departamentoCtrl = TextEditingController();
  final _salarioCtrl = TextEditingController();

  DateTime? _fechaIngreso;
  bool _activo = true;
  bool _guardando = false;

  bool get _esEdicion => widget.empleado != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final e = widget.empleado!;
      _nombreCtrl.text = '${e['nombre'] ?? ''}';
      _puestoCtrl.text = '${e['puesto'] ?? ''}';
      _departamentoCtrl.text = '${e['departamento'] ?? ''}';
      _salarioCtrl.text = '${e['salario_diario'] ?? ''}';
      _activo = e['activo'] == 1;
      final f = e['fecha_ingreso'];
      if (f != null) {
        _fechaIngreso = DateTime.tryParse('$f');
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _puestoCtrl.dispose();
    _departamentoCtrl.dispose();
    _salarioCtrl.dispose();
    super.dispose();
  }

  String? _fechaTexto() {
    if (_fechaIngreso == null) {
      return null;
    }
    final f = _fechaIngreso!;
    return '${f.year.toString().padLeft(4, '0')}-'
        '${f.month.toString().padLeft(2, '0')}-'
        '${f.day.toString().padLeft(2, '0')}';
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaIngreso ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Fecha de ingreso',
    );
    if (elegida != null) {
      setState(() => _fechaIngreso = elegida);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _guardando = true);

    final datos = <String, dynamic>{
      'nombre': _nombreCtrl.text.trim(),
      'puesto': _puestoCtrl.text.trim(),
      'departamento': _departamentoCtrl.text.trim(),
      'salario_diario': double.tryParse(_salarioCtrl.text.trim()) ?? 0,
      'activo': _activo ? 1 : 0,
      if (_fechaTexto() != null) 'fecha_ingreso': _fechaTexto(),
    };

    try {
      if (_esEdicion) {
        await ApiService.actualizarEmpleado('${widget.empleado!['id']}', datos);
      } else {
        await ApiService.crearEmpleado(datos);
      }
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
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
        title: Text(_esEdicion ? 'Editar empleado' : 'Nuevo empleado'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _puestoCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Puesto',
                  prefixIcon: Icon(Icons.work_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _departamentoCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Departamento',
                  prefixIcon: Icon(Icons.apartment_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salarioCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Salario diario',
                  helperText: 'Base del cálculo de nómina',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Campo requerido';
                  }
                  final n = double.tryParse(v.trim());
                  if (n == null) {
                    return 'Número inválido';
                  }
                  if (n <= 0) {
                    return 'Debe ser mayor a cero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Fecha de ingreso
              OutlinedButton.icon(
                onPressed: _elegirFecha,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                  _fechaIngreso == null
                      ? 'Elegir fecha de ingreso'
                      : 'Ingreso: ${_fechaTexto()}',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 8),

              // Baja lógica: se conserva el historial de asistencia.
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Empleado activo'),
                subtitle: const Text(
                  'Al desactivarlo deja de contar en la nómina, pero se '
                  'conserva su historial de asistencia.',
                ),
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
              ),
              const SizedBox(height: 24),

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
                  label: Text(
                    _esEdicion ? 'Guardar cambios' : 'Agregar empleado',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
