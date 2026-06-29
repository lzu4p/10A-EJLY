import 'package:flutter/material.dart';

// Llave global del Navigator: permite redirigir al login desde el ApiService
// (sin un BuildContext) cuando el token expira o es invalidado.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
