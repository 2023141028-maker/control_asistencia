import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageForCode(error.code));
    } catch (_) {
      throw const AuthFailure(
        'Ocurrió un error inesperado. Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw const AuthFailure('Ingresa tu correo electrónico.');
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_messageForPasswordResetCode(error.code));
    } catch (_) {
      throw const AuthFailure('No se pudo enviar el correo de recuperación.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException {
      throw const AuthFailure('No se pudo cerrar la sesión.');
    }
  }

  static String _messageForCode(String code) {
    return switch (code) {
      'invalid-email' => 'El correo electrónico no es válido.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'El correo o la contraseña son incorrectos.',
      'user-disabled' => 'Esta cuenta se encuentra deshabilitada.',
      'too-many-requests' =>
        'Demasiados intentos. Espera unos minutos e inténtalo nuevamente.',
      'network-request-failed' =>
        'No se pudo conectar. Revisa tu conexión a Internet.',
      _ => 'No fue posible iniciar sesión.',
    };
  }

  static String _messageForPasswordResetCode(String code) {
    return switch (code) {
      'invalid-email' => 'El correo electrónico no es válido.',
      'user-disabled' => 'Esta cuenta se encuentra deshabilitada.',
      'too-many-requests' =>
        'Demasiados intentos. Espera unos minutos e inténtalo nuevamente.',
      'network-request-failed' =>
        'No se pudo conectar. Revisa tu conexión a Internet.',
      _ => 'No se pudo enviar el correo de recuperación.',
    };
  }
}
