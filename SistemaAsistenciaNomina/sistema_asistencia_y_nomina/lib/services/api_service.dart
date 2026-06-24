import 'dart:convert';
import 'package:http/http.dart' as http;

const String _usersEndpoint = 'https://65f3ab00105614e654a0cefb.mockapi.io/users';
const String _productosEndpoint = 'https://65f3ab00105614e654a0cefb.mockapi.io/productos';

class ApiService {
  // Retorna el usuario completo si las credenciales son correctas, null si no
  static Future<Map<String, dynamic>?> login(
      String usuario, String contrasena) async {
    final response = await http.get(
      Uri.parse('$_usersEndpoint?username=$usuario'),
    );

    if (response.statusCode != 200) return null;

    final List data = jsonDecode(response.body);
    if (data.isEmpty) return null;

    final user = data.first as Map<String, dynamic>;
    if (user['password'] != contrasena) return null;

    return user;
  }

  // --- Usuarios ---

  static Future<List<Map<String, dynamic>>> fetchUsuarios() async {
    final response = await http.get(Uri.parse(_usersEndpoint));

    if (response.statusCode != 200) {
      throw Exception('Error al obtener usuarios: ${response.statusCode}');
    }

    final List data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> actualizarUsuario(
      String id, Map<String, dynamic> datos) async {
    final response = await http.put(
      Uri.parse('$_usersEndpoint/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar usuario: ${response.statusCode}');
    }
  }

  // --- Productos ---

  static Future<List<Map<String, dynamic>>> fetchProductos() async {
    final response = await http.get(Uri.parse(_productosEndpoint));

    if (response.statusCode != 200) {
      throw Exception('Error al obtener productos: ${response.statusCode}');
    }

    final List data = jsonDecode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  static Future<void> crearProducto(Map<String, dynamic> datos) async {
    final response = await http.post(
      Uri.parse(_productosEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );

    if (response.statusCode != 201) {
      throw Exception('Error al crear producto: ${response.statusCode}');
    }
  }

  static Future<void> actualizarProducto(
      String id, Map<String, dynamic> datos) async {
    final response = await http.put(
      Uri.parse('$_productosEndpoint/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(datos),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar producto: ${response.statusCode}');
    }
  }
}
