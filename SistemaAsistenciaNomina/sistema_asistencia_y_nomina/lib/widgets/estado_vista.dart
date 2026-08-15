import 'package:flutter/material.dart';

/// Vista de error de red, reutilizada por todas las pantallas que consumen la
/// API. Muestra un mensaje amigable y permite reintentar sin salir de la app.
class VistaError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;

  const VistaError({
    super.key,
    required this.mensaje,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: colores.error),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(color: colores.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje para cuando una consulta se completa pero no devuelve registros.
class VistaVacia extends StatelessWidget {
  final IconData icono;
  final String mensaje;

  const VistaVacia({
    super.key,
    required this.icono,
    required this.mensaje,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: colores.outline),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(color: colores.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
