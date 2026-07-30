import 'package:flutter/material.dart';

import '../../attendance/application/attendance_registration_service.dart';
import '../../attendance/data/firestore_attendance_repository.dart';
import '../../attendance/domain/attendance_repository.dart';
import '../../auth/domain/auth_repository.dart';
import '../../evidence/data/firebase_evidence_repository.dart';
import '../../evidence/data/image_picker_evidence_camera.dart';
import '../../home/presentation/home_screen.dart';
import '../../location/data/geolocator_location_service.dart';
import '../../location/domain/geofence_validator.dart';
import '../../location/domain/location_service.dart';
import '../../users/domain/user_profile.dart';
import '../domain/office.dart';
import '../domain/office_repository.dart';

class OfficeGate extends StatefulWidget {
  const OfficeGate({
    required this.officeId,
    required this.profile,
    required this.authRepository,
    required this.officeRepository,
    super.key,
  });

  final String officeId;
  final UserProfile profile;
  final AuthRepository authRepository;
  final OfficeRepository officeRepository;

  @override
  State<OfficeGate> createState() => _OfficeGateState();
}

class _OfficeGateState extends State<OfficeGate> {
  late Stream<Office?> _officeStream;

  late final LocationService _locationService;
  late final GeofenceValidator _geofenceValidator;
  late final AttendanceRepository _attendanceRepository;
  late final AttendanceRegistrationService _registrationService;

  @override
  void initState() {
    super.initState();

    _locationService = GeolocatorLocationService();
    _geofenceValidator = const GeofenceValidator();

    _attendanceRepository = FirestoreAttendanceRepository(
      geofenceValidator: _geofenceValidator,
    );

    _registrationService = AttendanceRegistrationService(
      attendanceRepository: _attendanceRepository,
      evidenceRepository: FirebaseEvidenceRepository(),
      evidenceCamera: ImagePickerEvidenceCamera(),
      locationService: _locationService,
      geofenceValidator: _geofenceValidator,
    );

    _officeStream = _watchOffice();
  }

  @override
  void didUpdateWidget(covariant OfficeGate oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.officeId != widget.officeId ||
        oldWidget.officeRepository != widget.officeRepository) {
      _officeStream = _watchOffice();
    }
  }

  Stream<Office?> _watchOffice() {
    return widget.officeRepository.watchOffice(officeId: widget.officeId);
  }

  void _retry() {
    setState(() {
      _officeStream = _watchOffice();
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
    return StreamBuilder<Office?>(
      stream: _officeStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;

          final message = error is OfficeFailure
              ? error.message
              : 'No se pudo cargar la sede.';

          return _OfficeMessageScreen(
            icon: Icons.location_off_outlined,
            title: 'Error al cargar la sede',
            message: message,
            onRetry: _retry,
            onSignOut: _signOut,
          );
        }

        final office = snapshot.data;

        if (office == null) {
          return _OfficeMessageScreen(
            icon: Icons.business_outlined,
            title: 'Sede no encontrada',
            message:
                'La sede asignada no existe. '
                'Comunícate con el administrador.',
            onSignOut: _signOut,
          );
        }

        if (!office.active) {
          return _OfficeMessageScreen(
            icon: Icons.block,
            title: 'Sede inactiva',
            message: 'La sede ${office.name} está desactivada temporalmente.',
            onSignOut: _signOut,
          );
        }

        return HomeScreen(
          profile: widget.profile,
          office: office,
          authRepository: widget.authRepository,
          locationService: _locationService,
          geofenceValidator: _geofenceValidator,
          attendanceRepository: _attendanceRepository,
          registrationService: _registrationService,
        );
      },
    );
  }
}

class _OfficeMessageScreen extends StatelessWidget {
  const _OfficeMessageScreen({
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
    return Scaffold(
      appBar: AppBar(title: const Text('Control de Asistencia')),
      body: Center(
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
                    Icon(
                      icon,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
    );
  }
}
