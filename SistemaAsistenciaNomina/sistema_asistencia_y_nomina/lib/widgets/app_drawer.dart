import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/empleados_screen.dart';
import '../screens/asistencia_screen.dart';
import '../screens/nomina_screen.dart';
import '../screens/usuarios_screen.dart';
import '../screens/login_screen.dart';

/// Menú lateral con los módulos del sistema.
class AppDrawer extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final String pantallaActual;

  const AppDrawer({
    super.key,
    required this.usuario,
    required this.pantallaActual,
  });

  /// Navega al módulo elegido reemplazando la pantalla actual, para que el
  /// historial no acumule una pila infinita al saltar entre secciones.
  void _ir(BuildContext context, String destino, Widget pantalla) {
    Navigator.pop(context);
    if (pantallaActual != destino) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => pantalla),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nombre = '${usuario['nombre'] ?? usuario['username'] ?? 'Usuario'}';
    final tipo = '${usuario['tipo'] ?? ''}';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            accountName: Text(
              nombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              '${usuario['username'] ?? ''} · $tipo',
              style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.8)),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),

          // Bienvenida
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Bienvenido, $nombre',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const Divider(),

          // --- Módulos del sistema ---
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.how_to_reg_outlined),
                  title: const Text('Asistencia'),
                  selected: pantallaActual == 'asistencia',
                  onTap: () => _ir(
                    context,
                    'asistencia',
                    AsistenciaScreen(usuario: usuario),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Empleados'),
                  selected: pantallaActual == 'empleados',
                  onTap: () => _ir(
                    context,
                    'empleados',
                    EmpleadosScreen(usuario: usuario),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Nómina'),
                  selected: pantallaActual == 'nomina',
                  onTap: () => _ir(
                    context,
                    'nomina',
                    NominaScreen(usuario: usuario),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: const Text('Administración de usuarios'),
                  selected: pantallaActual == 'usuarios',
                  onTap: () => _ir(
                    context,
                    'usuarios',
                    UsuariosScreen(usuario: usuario),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Cerrar sesión — SafeArea evita que quede bajo la barra de Android
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                final nav = Navigator.of(context);
                await ApiService.logout(); // invalida el token en el servidor
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
