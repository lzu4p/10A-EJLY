import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/estado_vista.dart';
import 'empleado_form_screen.dart';

/// Módulo de Empleados: listado, búsqueda, alta y edición.
class EmpleadosScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const EmpleadosScreen({super.key, required this.usuario});

  @override
  State<EmpleadosScreen> createState() => _EmpleadosScreenState();
}

class _EmpleadosScreenState extends State<EmpleadosScreen> {
  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _filtrados = [];
  bool _cargando = true;
  String? _error;

  final _busquedaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
    _busquedaCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await ApiService.fetchEmpleados();
      setState(() {
        _todos = data;
        _filtrar();
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _filtrar() {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtrados = List.from(_todos);
      } else {
        _filtrados = _todos.where((e) {
          return '${e['id']}'.toLowerCase().contains(q) ||
              '${e['nombre']}'.toLowerCase().contains(q) ||
              '${e['puesto']}'.toLowerCase().contains(q) ||
              '${e['departamento']}'.toLowerCase().contains(q) ||
              '${e['salario_diario']}'.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _abrirFormulario({Map<String, dynamic>? empleado}) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EmpleadoFormScreen(empleado: empleado),
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
        title: const Text('Empleados'),
        centerTitle: true,
      ),
      drawer: AppDrawer(
        usuario: widget.usuario,
        pantallaActual: 'empleados',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo empleado'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, puesto o departamento...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? VistaError(mensaje: _error!, onReintentar: _cargar)
                    : _filtrados.isEmpty
                        ? const VistaVacia(
                            icono: Icons.badge_outlined,
                            mensaje: 'Sin empleados que mostrar.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                            itemCount: _filtrados.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) =>
                                _tarjeta(_filtrados[i]),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> e) {
    final colores = Theme.of(context).colorScheme;
    final activo = e['activo'] == 1;
    final nombre = '${e['nombre'] ?? ''}';

    return Card(
      elevation: 0,
      color: colores.surfaceContainerHighest.withValues(alpha: 0.4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: activo
              ? colores.primaryContainer
              : colores.surfaceContainerHighest,
          child: Text(
            nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: activo ? colores.primary : colores.outline,
            ),
          ),
        ),
        title: Text(
          nombre,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: activo ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          '${e['puesto'] ?? ''} · ${e['departamento'] ?? ''}\n'
          '\$ ${e['salario_diario'] ?? 0} por día'
          '${activo ? '' : '  ·  DADO DE BAJA'}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Editar',
          onPressed: () => _abrirFormulario(empleado: e),
        ),
      ),
    );
  }
}
