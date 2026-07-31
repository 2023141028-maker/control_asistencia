import 'package:flutter/material.dart';

import '../../attendance/domain/attendance_day.dart';
import '../../auth/domain/auth_repository.dart';
import '../../users/domain/user_profile.dart';
import '../domain/admin_repository.dart';
import 'admin_attendances_screen.dart';
import 'admin_offices_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    required this.profile,
    required this.authRepository,
    required this.adminRepository,
    super.key,
  });

  final UserProfile profile;
  final AuthRepository authRepository;
  final AdminRepository adminRepository;

  @override
  State<AdminDashboardScreen> createState() {
    return _AdminDashboardScreenState();
  }
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

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
    final pages = <Widget>[
      _AdminOverview(
        profile: widget.profile,
        repository: widget.adminRepository,
        onNavigate: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      AdminUsersScreen(
        currentAdmin: widget.profile,
        repository: widget.adminRepository,
      ),
      AdminOfficesScreen(repository: widget.adminRepository),
      AdminAttendancesScreen(repository: widget.adminRepository),
    ];

    const titles = [
      'Panel administrativo',
      'Trabajadores',
      'Sedes',
      'Asistencias',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Personal',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Sedes',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Asistencias',
          ),
        ],
      ),
    );
  }
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({
    required this.profile,
    required this.repository,
    required this.onNavigate,
  });

  final UserProfile profile;
  final AdminRepository repository;
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserProfile>>(
      stream: repository.watchUsers(),
      builder: (context, usersSnapshot) {
        return StreamBuilder(
          stream: repository.watchOffices(),
          builder: (context, officesSnapshot) {
            return StreamBuilder(
              stream: repository.watchRecentAttendances(),
              builder: (context, attendancesSnapshot) {
                final error =
                    usersSnapshot.error ??
                    officesSnapshot.error ??
                    attendancesSnapshot.error;

                if (error != null) {
                  return _OverviewError(
                    message: error is AdminFailure
                        ? error.message
                        : 'No se pudo cargar el resumen administrativo.',
                  );
                }

                final waiting =
                    !usersSnapshot.hasData ||
                    !officesSnapshot.hasData ||
                    !attendancesSnapshot.hasData;

                if (waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = usersSnapshot.data!;
                final offices = officesSnapshot.data!;
                final attendances = attendancesSnapshot.data!;
                final today = AttendanceDay.fromInstant(DateTime.now()).value;

                final activeEmployees = users.where(
                  (user) =>
                      user.role == UserRole.employee &&
                      user.status == UserStatus.active,
                );

                final pendingUsers = users.where(
                  (user) => user.status == UserStatus.pending,
                );

                final activeOffices = offices.where((office) => office.active);

                final todayAttendances = attendances.where(
                  (attendance) => attendance.workDay.value == today,
                );

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 30,
                              child: Icon(Icons.admin_panel_settings, size: 34),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bienvenido, ${profile.fullName}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Gestiona personal, sedes y asistencias.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricCard(
                          icon: Icons.badge_outlined,
                          label: 'Trabajadores activos',
                          value: '${activeEmployees.length}',
                          onTap: () => onNavigate(1),
                        ),
                        _MetricCard(
                          icon: Icons.pending_actions,
                          label: 'Perfiles pendientes',
                          value: '${pendingUsers.length}',
                          onTap: () => onNavigate(1),
                        ),
                        _MetricCard(
                          icon: Icons.business_outlined,
                          label: 'Sedes activas',
                          value: '${activeOffices.length}',
                          onTap: () => onNavigate(2),
                        ),
                        _MetricCard(
                          icon: Icons.today,
                          label: 'Asistencias de hoy',
                          value: '${todayAttendances.length}',
                          onTap: () => onNavigate(3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Acciones rápidas',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: () => onNavigate(1),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Gestionar trabajadores'),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: () => onNavigate(2),
                              icon: const Icon(Icons.add_business),
                              label: const Text('Gestionar sedes'),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: () => onNavigate(3),
                              icon: const Icon(Icons.search),
                              label: const Text('Revisar asistencias'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 52) / 2;

    return SizedBox(
      width: width.clamp(150, 360).toDouble(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 14),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewError extends StatelessWidget {
  const _OverviewError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
