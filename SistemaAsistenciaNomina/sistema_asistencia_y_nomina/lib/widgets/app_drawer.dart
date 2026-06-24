import 'package:flutter/material.dart';
import '../screens/productos_screen.dart';
import '../screens/usuarios_screen.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final String pantallaActual;

  const AppDrawer({
    super.key,
    required this.usuario,
    required this.pantallaActual,
  });

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
              style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.8)),
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

          // Navegación
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Productos'),
            selected: pantallaActual == 'productos',
            onTap: () {
              Navigator.pop(context);
              if (pantallaActual != 'productos') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductosScreen(usuario: usuario),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Administración de usuarios'),
            selected: pantallaActual == 'usuarios',
            onTap: () {
              Navigator.pop(context);
              if (pantallaActual != 'usuarios') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UsuariosScreen(usuario: usuario),
                  ),
                );
              }
            },
          ),

          const Spacer(),
          const Divider(),

          // Cerrar sesión — SafeArea evita que quede bajo la barra de Android
          SafeArea(
            top: false,
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
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
