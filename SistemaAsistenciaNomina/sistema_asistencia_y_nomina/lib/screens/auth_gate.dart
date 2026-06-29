import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'productos_screen.dart';

/// Pantalla inicial: decide a dónde entrar al abrir la app.
///
/// Lee el token guardado y lo valida contra la API (/me). Si sigue vigente
/// entra directo a Productos; si no (expirado, logout previo, crash) va al login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _decidir();
  }

  Future<void> _decidir() async {
    final usuario = await ApiService.validarSesion();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => usuario != null
            ? ProductosScreen(usuario: usuario)
            : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
