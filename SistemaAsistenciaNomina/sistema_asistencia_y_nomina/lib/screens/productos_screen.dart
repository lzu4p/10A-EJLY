import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_drawer.dart';
import 'producto_form_screen.dart';

class ProductosScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const ProductosScreen({super.key, required this.usuario});

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
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
      final data = await ApiService.fetchProductos();
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
        _filtrados = _todos.where((p) {
          return '${p['id']}'.toLowerCase().contains(q) ||
              '${p['nombre']}'.toLowerCase().contains(q) ||
              '${p['categoria']}'.toLowerCase().contains(q) ||
              '${p['precio']}'.toLowerCase().contains(q) ||
              '${p['cantidad']}'.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _irAgregar() async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductoFormScreen()),
    );
    if (resultado == true) _cargar();
  }

  Future<void> _irEditar(Map<String, dynamic> producto) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductoFormScreen(producto: producto),
      ),
    );
    if (resultado == true) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        centerTitle: true,
      ),
      drawer: AppDrawer(
        usuario: widget.usuario,
        pantallaActual: 'productos',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irAgregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
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
                                  DataColumn(label: Text('Producto')),
                                  DataColumn(label: Text('Categoría')),
                                  DataColumn(
                                      label: Text('Precio'), numeric: true),
                                  DataColumn(
                                      label: Text('Cant. Disponible'),
                                      numeric: true),
                                  DataColumn(label: Text('Acción')),
                                ],
                                rows: _filtrados.map((p) {
                                  return DataRow(cells: [
                                    DataCell(Text('${p['id'] ?? ''}')),
                                    DataCell(Text('${p['nombre'] ?? ''}')),
                                    DataCell(Text('${p['categoria'] ?? ''}')),
                                    DataCell(Text('${p['precio'] ?? ''}')),
                                    DataCell(Text('${p['cantidad'] ?? ''}')),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Editar',
                                        onPressed: () => _irEditar(p),
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
