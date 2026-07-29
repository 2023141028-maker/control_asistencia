import 'package:control_asistencia/app/app.dart';
import 'package:control_asistencia/features/auth/domain/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  @override
  Stream<User?> authStateChanges() => Stream<User?>.value(null);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('muestra el formulario cuando no existe una sesión', (
    tester,
  ) async {
    await tester.pumpWidget(
      AttendanceApp(authRepository: FakeAuthRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Control de Asistencia'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
