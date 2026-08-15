import 'package:flutter/material.dart';
import 'app_globals.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema Asistencia y Nómina',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      // Ruta usada para volver al login cuando expira el token.
      routes: {
        '/login': (_) => const LoginScreen(),
      },
      home: const AuthGate(),
    );
  }
}
