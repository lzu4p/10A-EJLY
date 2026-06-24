import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import 'usuario_form_screen.dart';

class UsuariosScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const UsuariosScreen({super.key, required this.usuario});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
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
      final data = await ApiService.fetchUsuarios();
      setState(() {
        _todos = data;
        _filtrar();
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _filtrar() {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtrados = List.from(_todos);
      } else {
        _filtrados = _todos.where((u) {
          return '${u['id']}'.toLowerCase().contains(q) ||
              '${u['nombre']}'.toLowerCase().contains(q) ||
              '${u['username']}'.toLowerCase().contains(q) ||
              '${u['tipo']}'.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _irEditar(Map<String, dynamic> user) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UsuarioFormScreen(usuario: user),
      ),
    );
    if (resultado == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración de usuarios'),
        centerTitle: true,
      ),
      drawer: AppDrawer(
        usuario: widget.usuario,
        pantallaActual: 'usuarios',
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _busquedaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar en todos los campos...',
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
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error: $_error',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      )
                    : _filtrados.isEmpty
                        ? const Center(child: Text('Sin resultados.'))
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                ),
                                columns: const [
                                  DataColumn(label: Text('ID')),
                                  DataColumn(label: Text('Nombre')),
                                  DataColumn(label: Text('Usuario')),
                                  DataColumn(label: Text('Función')),
                                  DataColumn(label: Text('Acción')),
                                ],
                                rows: _filtrados.map((u) {
                                  return DataRow(cells: [
                                    DataCell(Text('${u['id'] ?? ''}')),
                                    DataCell(Text('${u['nombre'] ?? ''}')),
                                    DataCell(Text('${u['username'] ?? ''}')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: u['tipo'] == 'admin'
                                              ? Colors.blue.shade100
                                              : Colors.green.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${u['tipo'] ?? ''}',
                                          style: TextStyle(
                                            color: u['tipo'] == 'admin'
                                                ? Colors.blue.shade800
                                                : Colors.green.shade800,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Editar',
                                        onPressed: () => _irEditar(u),
                                      ),
                                    ),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
