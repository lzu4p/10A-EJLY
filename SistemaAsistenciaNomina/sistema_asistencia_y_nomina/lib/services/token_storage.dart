import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro del token de sesión.
///
/// En Android usa **EncryptedSharedPreferences** (cifrado), de modo que el
/// token sobrevive al cierre de la app pero queda protegido en disco.
class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _key = 'access_token';

  static Future<void> guardar(String token) =>
      _storage.write(key: _key, value: token);

  static Future<String?> leer() => _storage.read(key: _key);

  static Future<void> borrar() => _storage.delete(key: _key);
}
