import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../home/presentation/home_screen.dart';
import '../domain/auth_repository.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authRepository.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('No se pudo comprobar la sesión.')),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return LoginScreen(authRepository: authRepository);
        }

        return HomeScreen(user: user, authRepository: authRepository);
      },
    );
  }
}
