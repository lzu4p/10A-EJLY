import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_asistencia_y_nomina/main.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla de login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.text('Acceder'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });
}
