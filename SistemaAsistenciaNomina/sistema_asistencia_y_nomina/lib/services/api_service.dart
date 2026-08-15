import 'dart:convert';
import 'dart:io';
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

/// Manejo de error de red: se lanza cuando no hay conexión con el servidor
/// (sin internet, API apagada, host inalcanzable).
class ErrorDeRed implements Exception {
  final String mensaje;
  ErrorDeRed(
      [this.mensaje =
          'Sin conexión al servidor.\nVerifica tu red o que la API esté activa.']);
  @override
  String toString() => mensaje;
}

class ApiService {
  // Ejecuta una petición HTTP convirtiendo los fallos de conexión
  // (SocketException, ClientException) en un ErrorDeRed amigable.
  static Future<http.Response> _enviar(
      Future<http.Response> Function() peticion) async {
    try {
      return await peticion();
    } on SocketException {
      throw ErrorDeRed();
    } on http.ClientException {
      throw ErrorDeRed();
    }
  }

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

  // Extrae el mensaje de error que envía FastAPI en el campo "detail".
  static String _detalle(http.Response r, String porDefecto) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['detail'] != null) {
        return '${d['detail']}';
      }
    } catch (_) {
      // El cuerpo no era JSON: se usa el mensaje por defecto.
    }
    return porDefecto;
  }

  // ---------- Autenticación ----------

  /// Inicia sesión. Guarda el token y devuelve los datos del usuario, o null
  /// si las credenciales son incorrectas.
  static Future<Map<String, dynamic>?> login(
      String usuario, String contrasena) async {
    final r = await _enviar(() => http.post(
          Uri.parse('$_base/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': usuario, 'password': contrasena}),
        ));
    if (r.statusCode != 200) {
      return null;
    }

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
      if (token == null) {
        return null;
      }
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
    final h = await _headers();
    final r =
        await _enviar(() => http.get(Uri.parse('$_base/usuarios'), headers: h));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception('Error al obtener usuarios: ${r.statusCode}');
    }
    final List data = jsonDecode(r.body);
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> crearUsuario(Map<String, dynamic> datos) async {
    final h = await _headers();
    final r = await _enviar(() => http.post(
          Uri.parse('$_base/usuarios'),
          headers: h,
          body: jsonEncode(datos),
        ));
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
    final h = await _headers();
    final r = await _enviar(() => http.put(
          Uri.parse('$_base/usuarios/$id'),
          headers: h,
          body: jsonEncode(datos),
        ));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception('Error al actualizar usuario: ${r.statusCode}');
    }
  }

  // ---------- Empleados ----------

  static Future<List<Map<String, dynamic>>> fetchEmpleados() async {
    final h = await _headers();
    final r = await _enviar(
        () => http.get(Uri.parse('$_base/empleados'), headers: h));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception('Error al obtener empleados: ${r.statusCode}');
    }
    final List data = jsonDecode(r.body);
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> crearEmpleado(Map<String, dynamic> datos) async {
    final h = await _headers();
    final r = await _enviar(() => http.post(
          Uri.parse('$_base/empleados'),
          headers: h,
          body: jsonEncode(datos),
        ));
    _verificarSesion(r);
    if (r.statusCode != 201) {
      throw Exception(_detalle(r, 'Error al crear empleado: ${r.statusCode}'));
    }
  }

  static Future<void> actualizarEmpleado(
      String id, Map<String, dynamic> datos) async {
    final h = await _headers();
    final r = await _enviar(() => http.put(
          Uri.parse('$_base/empleados/$id'),
          headers: h,
          body: jsonEncode(datos),
        ));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception(
          _detalle(r, 'Error al actualizar empleado: ${r.statusCode}'));
    }
  }

  // ---------- Asistencia ----------

  /// Registros de asistencia. Se puede filtrar por día o por empleado.
  static Future<List<Map<String, dynamic>>> fetchAsistencias({
    String? fecha,
    int? empleadoId,
  }) async {
    final h = await _headers();
    final params = <String, String>{};
    if (fecha != null) params['fecha'] = fecha;
    if (empleadoId != null) params['empleado_id'] = '$empleadoId';

    final uri =
        Uri.parse('$_base/asistencias').replace(queryParameters: params);
    final r = await _enviar(() => http.get(uri, headers: h));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception('Error al obtener asistencias: ${r.statusCode}');
    }
    final List data = jsonDecode(r.body);
    return data.cast<Map<String, dynamic>>();
  }

  /// Estado de la checada del usuario en el día actual (null si no ha checado).
  static Future<Map<String, dynamic>?> miAsistenciaDeHoy() async {
    final h = await _headers();
    final r = await _enviar(
        () => http.get(Uri.parse('$_base/asistencias/hoy'), headers: h));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(r.body);
    return data == null ? null : data as Map<String, dynamic>;
  }

  /// Marca la entrada del usuario. Devuelve el mensaje de confirmación.
  static Future<String> checarEntrada() async {
    final h = await _headers();
    final r = await _enviar(
        () => http.post(Uri.parse('$_base/asistencias/checar'), headers: h));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception(_detalle(r, 'No se pudo registrar la entrada'));
    }
    return '${jsonDecode(r.body)['mensaje']}';
  }

  /// Marca la salida del usuario. Devuelve el mensaje de confirmación.
  static Future<String> checarSalida() async {
    final h = await _headers();
    final r = await _enviar(() =>
        http.post(Uri.parse('$_base/asistencias/checar-salida'), headers: h));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception(_detalle(r, 'No se pudo registrar la salida'));
    }
    return '${jsonDecode(r.body)['mensaje']}';
  }

  /// Captura manual hecha por el administrador.
  static Future<void> capturarAsistencia(Map<String, dynamic> datos) async {
    final h = await _headers();
    final r = await _enviar(() => http.post(
          Uri.parse('$_base/asistencias'),
          headers: h,
          body: jsonEncode(datos),
        ));
    _verificarSesion(r);
    if (r.statusCode != 201) {
      throw Exception(_detalle(r, 'Error al capturar asistencia'));
    }
  }

  static Future<void> actualizarAsistencia(
      String id, Map<String, dynamic> datos) async {
    final h = await _headers();
    final r = await _enviar(() => http.put(
          Uri.parse('$_base/asistencias/$id'),
          headers: h,
          body: jsonEncode(datos),
        ));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception(_detalle(r, 'Error al actualizar asistencia'));
    }
  }

  // ---------- Nómina ----------

  /// Calcula la nómina del periodo: días trabajados x salario diario.
  static Future<Map<String, dynamic>> calcularNomina({
    String? inicio,
    String? fin,
  }) async {
    final h = await _headers();
    final params = <String, String>{};
    if (inicio != null) params['inicio'] = inicio;
    if (fin != null) params['fin'] = fin;

    final uri = Uri.parse('$_base/nomina').replace(queryParameters: params);
    final r = await _enviar(() => http.get(uri, headers: h));
    _verificarSesion(r);
    if (r.statusCode != 200) {
      throw Exception('Error al calcular la nómina: ${r.statusCode}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
