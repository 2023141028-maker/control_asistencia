import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.user,
    required this.authRepository,
    super.key,
  });

  final User user;
  final AuthRepository authRepository;

  Future<void> _signOut(BuildContext context) async {
    try {
      await authRepository.signOut();
    } on AuthFailure catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Asistencia'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user,
                size: 80,
                color: Color(0xFF1565C0),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sesión iniciada correctamente',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(user.email ?? 'Usuario autenticado'),
            ],
          ),
        ),
      ),
    );
  }
}
