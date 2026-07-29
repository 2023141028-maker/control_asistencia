import 'package:firebase_auth/firebase_auth.dart';

abstract interface class AuthRepository {
  Stream<User?> authStateChanges();

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
