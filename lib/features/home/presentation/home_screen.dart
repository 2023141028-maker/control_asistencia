import 'package:flutter/material.dart';

import '../../auth/domain/auth_repository.dart';
import '../../location/domain/geofence_validator.dart';
import '../../location/domain/location_service.dart';
import '../../location/presentation/location_verification_card.dart';
import '../../offices/domain/office.dart';
import '../../users/domain/user_profile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.profile,
    required this.office,
    required this.authRepository,
    required this.locationService,
    required this.geofenceValidator,
    super.key,
  });

  final UserProfile profile;
  final Office office;
  final AuthRepository authRepository;
  final LocationService locationService;
  final GeofenceValidator geofenceValidator;

  Future<void> _signOut(BuildContext context) async {
    try {
      await authRepository.signOut();
    } on AuthFailure catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar la sesión.')),
      );
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
                    _InformationRow(
                      icon: Icons.badge_outlined,
                      label: 'Código',
                      value: profile.employeeCode,
                    ),
                    const Divider(),
                    _InformationRow(
                      icon: Icons.email_outlined,
                      label: 'Correo',
                      value: profile.email,
                    ),
                    const Divider(),
                    _InformationRow(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Rol',
                      value: profile.role.label,
                    ),
                    const Divider(),
                    _InformationRow(
                      icon: Icons.verified_outlined,
                      label: 'Estado',
                      value: profile.status.label,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sede asignada',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _InformationRow(
                      icon: Icons.business_outlined,
                      label: 'Sede',
                      value: office.name,
                    ),
                    const Divider(),
                    _InformationRow(
                      icon: Icons.place_outlined,
                      label: 'Dirección',
                      value: office.address,
                    ),
                    const Divider(),
                    _InformationRow(
                      icon: Icons.radar,
                      label: 'Radio permitido',
                      value: '${office.radiusMeters.toStringAsFixed(0)} metros',
                    ),
                    const Divider(),
                    _InformationRow(
                      icon: Icons.gps_fixed,
                      label: 'Precisión máxima',
                      value:
                          '${office.maxAccuracyMeters.toStringAsFixed(0)} metros',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            LocationVerificationCard(
              office: office,
              locationService: locationService,
              geofenceValidator: geofenceValidator,
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: Icon(Icons.security, color: colors.primary),
                title: const Text('Acceso verificado'),
                subtitle: const Text(
                  'Firebase Authentication, el perfil y la sede de Firestore '
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

class _InformationRow extends StatelessWidget {
  const _InformationRow({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
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
