import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UsuarioFormScreen extends StatefulWidget {
  final Map<String, dynamic>? usuario; // null = alta de nuevo usuario

  const UsuarioFormScreen({super.key, this.usuario});

  @override
  State<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends State<UsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _mostrarPassword = false; // ver/ocultar — solo en alta de nuevo usuario
  bool _restablecer = false;     // mostrar campo de nueva contraseña — en edición
  bool _guardando = false;
  String _tipoSeleccionado = 'user';

  static const _opciones = ['admin', 'user'];

  bool get _esEdicion => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final u = widget.usuario!;
      _nombreCtrl.text = '${u['nombre'] ?? ''}';
      _usernameCtrl.text = '${u['username'] ?? ''}';
      final tipo = '${u['tipo'] ?? 'user'}';
      _tipoSeleccionado = _opciones.contains(tipo) ? tipo : 'user';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final datos = <String, dynamic>{
      'nombre': _nombreCtrl.text.trim(),
      'username': _usernameCtrl.text.trim(),
      'tipo': _tipoSeleccionado,
    };

    // Contraseña: obligatoria en alta; en edición solo si se restablece.
    if (!_esEdicion) {
      datos['password'] = _passwordCtrl.text;
    } else if (_restablecer && _passwordCtrl.text.isNotEmpty) {
      datos['password'] = _passwordCtrl.text;
    }

    try {
      if (_esEdicion) {
        await ApiService.actualizarUsuario('${widget.usuario!['id']}', datos);
      } else {
        await ApiService.crearUsuario(datos);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar usuario' : 'Nuevo usuario'),
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
                  labelText: 'Nombre real',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),

              // ----- Contraseña -----
              if (!_esEdicion)
                // ALTA: obligatoria y con opción de ver/ocultar.
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: !_mostrarPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_mostrarPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      tooltip: _mostrarPassword ? 'Ocultar' : 'Mostrar',
                      onPressed: () => setState(
                          () => _mostrarPassword = !_mostrarPassword),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Campo requerido' : null,
                )
              else ...[
                // EDICIÓN: la contraseña está encriptada y no puede mostrarse.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Restablecer contraseña'),
                  subtitle: const Text(
                    'La contraseña actual está encriptada y no puede verse.',
                  ),
                  value: _restablecer,
                  onChanged: (val) => setState(() {
                    _restablecer = val;
                    if (!val) _passwordCtrl.clear();
                  }),
                ),
                if (_restablecer)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nueva contraseña',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (_restablecer && (v == null || v.isEmpty)) {
                          return 'Ingresa la nueva contraseña';
                        }
                        return null;
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 16),

              // Selector de función
              DropdownButtonFormField<String>(
                initialValue: _tipoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Función',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _opciones
                    .map((op) => DropdownMenuItem(
                          value: op,
                          child:
                              Text(op == 'admin' ? 'Administrador' : 'Usuario'),
                        ))
                    .toList(),
                onChanged: (val) =>
                    setState(() => _tipoSeleccionado = val ?? 'user'),
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
                      : Icon(_esEdicion
                          ? Icons.save_outlined
                          : Icons.person_add_outlined),
                  label: Text(
                    _esEdicion ? 'Guardar cambios' : 'Agregar usuario',
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
