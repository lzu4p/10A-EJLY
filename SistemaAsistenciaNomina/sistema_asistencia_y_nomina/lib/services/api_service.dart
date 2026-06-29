import 'dart:convert';
import 'package:http/http.dart' as http;

import '../app_globals.dart';
import 'token_storage.dart';

// Base de la API Python (FastAPI).
// 10.0.2.2 = la PC host vista desde el emulador Android.
// Para un dispositivo físico, cambiar por la IP LAN de la PC (ej. 192.168.x.x).
const String _base = 'http://10.0.2.2:8000';

/// Se lanza cuando el token deja de ser válido (expiró / logout / login nuevo).
class SesionExpirada implements Exception {
  final String mensaje;
  SesionExpirada([this.mensaje = 'Sesión expirada. Inicia sesión de nuevo.']);
  @override
  String toString() => mensaje;
}

class ApiService {
  // Encabezados con el token guardado (si existe).
  static Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.leer();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Si la API responde 401, limpia la sesión y vuelve al login.
  static void _verificarSesion(http.Response r) {
    if (r.statusCode == 401) {
      TokenStorage.borrar();
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/login', (_) => false);
      throw SesionExpirada();
    }
  }

  // ---------- Autenticación ----------

  /// Inicia sesión. Guarda el token y devuelve los datos del usuario, o null
  /// si las credenciales son incorrectas.
  static Future<Map<String, dynamic>?> login(
      String usuario, String contrasena) async {
    final r = await http.post(
      Uri.parse('$_base/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': usuario, 'password': contrasena}),
    );
    if (r.statusCode != 200) return null;

    final data = jsonDecode(r.body) as Map<String, dynamic>;
    await TokenStorage.guardar(data['access_token'] as String);
    return data['usuario'] as Map<String, dynamic>;
  }

  /// Cierra sesión en el servidor (invalida el token) y borra el token local.
  static Future<void> logout() async {
    try {
      await http.post(Uri.parse('$_base/logout'), headers: await _headers());
    } catch (_) {
      // Aunque falle la llamada, igual limpiamos el token local.
    } finally {
      await TokenStorage.borrar();
    }
  }

  /// Valida el token guardado al abrir la app. Devuelve el usuario o null.
  static Future<Map<String, dynamic>?> validarSesion() async {
    try {
      final token = await TokenStorage.leer();
      if (token == null) return null;
      final r =
          await http.get(Uri.parse('$_base/me'), headers: await _headers());
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
      await TokenStorage.borrar();
      return null;
    } catch (_) {
      return null;
    }
  }

  // ---------- Usuarios ----------

  static Future<List<Map<String, dynamic>>> fetchUsuarios() async {
    final r =
        await http.get(Uri.parse('$_base/usuarios'), headers: await _headers());
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception('Error al obtener usuarios: ${r.statusCode}');
    }
    final List data = jsonDecode(r.body);
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> crearUsuario(Map<String, dynamic> datos) async {
    final r = await http.post(
      Uri.parse('$_base/usuarios'),
      headers: await _headers(),
      body: jsonEncode(datos),
    );
    _verificarSesion(r);
    if (r.statusCode == 409) {
      throw Exception('El nombre de usuario ya existe');
    }
    if (r.statusCode != 201) {
      throw Exception('Error al crear usuario: ${r.statusCode}');
    }
  }

  static Future<void> actualizarUsuario(
      String id, Map<String, dynamic> datos) async {
    final r = await http.put(
      Uri.parse('$_base/usuarios/$id'),
      headers: await _headers(),
      body: jsonEncode(datos),
    );
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception('Error al actualizar usuario: ${r.statusCode}');
    }
  }

  // ---------- Productos ----------

  static Future<List<Map<String, dynamic>>> fetchProductos() async {
    final r = await http.get(
        Uri.parse('$_base/productos'), headers: await _headers());
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception('Error al obtener productos: ${r.statusCode}');
    }
    final List data = jsonDecode(r.body);
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> crearProducto(Map<String, dynamic> datos) async {
    final r = await http.post(
      Uri.parse('$_base/productos'),
      headers: await _headers(),
      body: jsonEncode(datos),
    );
    _verificarSesion(r);
    if (r.statusCode != 201) {
      throw Exception('Error al crear producto: ${r.statusCode}');
    }
  }

  static Future<void> actualizarProducto(
      String id, Map<String, dynamic> datos) async {
    final r = await http.put(
      Uri.parse('$_base/productos/$id'),
      headers: await _headers(),
      body: jsonEncode(datos),
    );
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception('Error al actualizar producto: ${r.statusCode}');
    }
  }
}
