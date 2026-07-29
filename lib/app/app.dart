import 'package:flutter/material.dart';

import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/users/domain/user_repository.dart';

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({
    required this.authRepository,
    required this.userRepository,
    super.key,
  });

  final AuthRepository authRepository;
  final UserRepository userRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control de Asistencia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: AuthGate(
        authRepository: authRepository,
        userRepository: userRepository,
      ),
    );
  }
}
