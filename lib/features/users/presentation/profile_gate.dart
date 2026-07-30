import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';
import '../../offices/domain/office_repository.dart';
import '../../offices/presentation/office_gate.dart';
import '../domain/user_profile.dart';
import '../domain/user_repository.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    required this.user,
    required this.authRepository,
    required this.userRepository,
    required this.officeRepository,
    super.key,
  });

  final User user;
  final AuthRepository authRepository;
  final UserRepository userRepository;
  final OfficeRepository officeRepository;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Stream<UserProfile?> _profileStream;

  @override
  void initState() {
    super.initState();
    _profileStream = _watchProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.user.uid != widget.user.uid ||
        oldWidget.userRepository != widget.userRepository) {
      _profileStream = _watchProfile();
    }
  }

  Stream<UserProfile?> _watchProfile() {
    return widget.userRepository.watchProfile(uid: widget.user.uid);
  }

  void _retry() {
    setState(() {
      _profileStream = _watchProfile();
    });
  }

  Future<void> _signOut() async {
    try {
      await widget.authRepository.signOut();
    } on AuthFailure catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar la sesión.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingProfileScreen();
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          final message = error is UserProfileFailure
              ? error.message
              : 'No se pudo cargar el perfil.';

          return _AccessStateScreen(
            icon: Icons.cloud_off,
            title: 'No pudimos cargar tu perfil',
            message: message,
            onRetry: _retry,
            onSignOut: _signOut,
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          return _AccessStateScreen(
            icon: Icons.person_off_outlined,
            title: 'Cuenta sin autorización',
            message:
                'Tu cuenta está autenticada, pero todavía no tiene un perfil '
                'autorizado por el administrador.',
            onSignOut: _signOut,
          );
        }

        return switch (profile.status) {
          UserStatus.active =>
            profile.officeId == null
                ? _AccessStateScreen(
                    icon: Icons.business_outlined,
                    title: 'Sin sede asignada',
                    message:
                        'Tu perfil está activo, pero todavía no tiene una '
                        'sede asignada.',
                    onSignOut: _signOut,
                  )
                : OfficeGate(
                    officeId: profile.officeId!,
                    profile: profile,
                    authRepository: widget.authRepository,
                    officeRepository: widget.officeRepository,
                  ),
          UserStatus.pending => _AccessStateScreen(
            icon: Icons.schedule,
            title: 'Cuenta pendiente',
            message:
                'Tu perfil está pendiente de aprobación. Cuando un '
                'administrador lo active, el acceso se habilitará '
                'automáticamente.',
            onSignOut: _signOut,
          ),
          UserStatus.inactive => _AccessStateScreen(
            icon: Icons.block,
            title: 'Cuenta inactiva',
            message:
                'Esta cuenta fue desactivada. Comunícate con el administrador.',
            onSignOut: _signOut,
          ),
        };
      },
    );
  }
}

class _LoadingProfileScreen extends StatelessWidget {
  const _LoadingProfileScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AccessStateScreen extends StatelessWidget {
  const _AccessStateScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.onSignOut,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onSignOut;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Control de Asistencia')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 72, color: colors.primary),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(message, textAlign: TextAlign.center),
                      if (onRetry != null) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: onSignOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
