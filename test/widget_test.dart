import 'package:control_asistencia/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra la pantalla inicial de la aplicación', (tester) async {
    await tester.pumpWidget(const AttendanceApp());

    expect(find.text('Control de Asistencia'), findsOneWidget);
    expect(find.text('Firebase conectado correctamente'), findsOneWidget);
  });
}
