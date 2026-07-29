import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';
import '../../users/domain/user_profile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.profile,
    required this.authRepository,
    super.key,
  });

  final UserProfile profile;
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
    final colors = Theme.of(context).colorScheme;

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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              color: colors.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: colors.primary,
                      child: Icon(
                        Icons.person,
                        color: colors.onPrimary,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.fullName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(profile.role.label),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Perfil autorizado',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _ProfileRow(
                      icon: Icons.badge_outlined,
                      label: 'Código',
                      value: profile.employeeCode,
                    ),
                    const Divider(),
                    _ProfileRow(
                      icon: Icons.email_outlined,
                      label: 'Correo',
                      value: profile.email,
                    ),
                    const Divider(),
                    _ProfileRow(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Rol',
                      value: profile.role.label,
                    ),
                    const Divider(),
                    _ProfileRow(
                      icon: Icons.verified_outlined,
                      label: 'Estado',
                      value: profile.status.label,
                    ),
                    const Divider(),
                    _ProfileRow(
                      icon: Icons.business_outlined,
                      label: 'Oficina',
                      value: profile.officeId ?? 'Sin asignar',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: Icon(Icons.security, color: colors.primary),
                title: const Text('Acceso verificado'),
                subtitle: const Text(
                  'Firebase Authentication y el perfil de Firestore '
                  'fueron validados correctamente.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(label)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
