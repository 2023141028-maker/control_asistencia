import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../offices/domain/office_repository.dart';
import '../../users/domain/user_repository.dart';
import '../../users/presentation/profile_gate.dart';
import '../domain/auth_repository.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    required this.authRepository,
    required this.userRepository,
    required this.officeRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final UserRepository userRepository;
  final OfficeRepository officeRepository;

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

        return ProfileGate(
          user: user,
          authRepository: authRepository,
          userRepository: userRepository,
          officeRepository: officeRepository,
        );
      },
    );
  }
}
