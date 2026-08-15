import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_asistencia_y_nomina/main.dart';

void main() {
  testWidgets('La app arranca mostrando el AuthGate (verificando sesion)',
      (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    // En el primer frame, AuthGate muestra el indicador de carga mientras
    // valida si hay una sesion guardada.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
