import 'package:flutter/material.dart';

import '../../attendance/domain/attendance_record.dart';
import '../../offices/domain/office.dart';
import '../../users/domain/user_profile.dart';
import '../domain/admin_repository.dart';

class AdminAttendancesScreen extends StatefulWidget {
  const AdminAttendancesScreen({required this.repository, super.key});

  final AdminRepository repository;

  @override
  State<AdminAttendancesScreen> createState() {
    return _AdminAttendancesScreenState();
  }
}

class _AdminAttendancesScreenState extends State<AdminAttendancesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserProfile>>(
      stream: widget.repository.watchUsers(),
      builder: (context, usersSnapshot) {
        if (usersSnapshot.hasError) {
          return _AttendanceMessage(
            icon: Icons.cloud_off,
            message: _errorMessage(usersSnapshot.error),
          );
        }

        if (!usersSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<Office>>(
          stream: widget.repository.watchOffices(),
          builder: (context, officesSnapshot) {
            if (officesSnapshot.hasError) {
              return _AttendanceMessage(
                icon: Icons.cloud_off,
                message: _errorMessage(officesSnapshot.error),
              );
            }

            if (!officesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<List<AttendanceRecord>>(
              stream: widget.repository.watchRecentAttendances(),
              builder: (context, attendanceSnapshot) {
                if (attendanceSnapshot.hasError) {
                  return _AttendanceMessage(
                    icon: Icons.cloud_off,
                    message: _errorMessage(attendanceSnapshot.error),
                  );
                }

                if (!attendanceSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final usersById = {
                  for (final user in usersSnapshot.data!) user.uid: user,
                };

                final officesById = {
                  for (final office in officesSnapshot.data!) office.id: office,
                };

                final normalizedQuery = _query.trim().toLowerCase();

                final records = attendanceSnapshot.data!
                    .where((record) {
                      if (normalizedQuery.isEmpty) {
                        return true;
                      }

                      final user = usersById[record.userId];
                      final office = officesById[record.officeId];

                      return record.workDay.value.contains(normalizedQuery) ||
                          record.status.label.toLowerCase().contains(
                            normalizedQuery,
                          ) ||
                          record.officeId.toLowerCase().contains(
                            normalizedQuery,
                          ) ||
                          (user?.fullName.toLowerCase().contains(
                                normalizedQuery,
                              ) ??
                              false) ||
                          (user?.employeeCode.toLowerCase().contains(
                                normalizedQuery,
                              ) ??
                              false) ||
                          (office?.name.toLowerCase().contains(
                                normalizedQuery,
                              ) ??
                              false);
                    })
                    .toList(growable: false);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() => _query = value);
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Buscar por trabajador, sede, estado o fecha',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: records.isEmpty
                          ? const _AttendanceMessage(
                              icon: Icons.event_busy,
                              message: 'No se encontraron asistencias.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: records.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final record = records[index];
                                final user = usersById[record.userId];
                                final office = officesById[record.officeId];

                                return _AttendanceCard(
                                  record: record,
                                  user: user,
                                  office: office,
                                  onOpen: () => _showAttendance(
                                    record: record,
                                    user: user,
                                    office: office,
                                  ),
                                );
                              },
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

  Future<void> _showAttendance({
    required AttendanceRecord record,
    required UserProfile? user,
    required Office? office,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => _AttendanceDetailDialog(
        record: record,
        user: user,
        office: office,
        repository: widget.repository,
      ),
    );
  }

  String _errorMessage(Object? error) {
    return error is AdminFailure
        ? error.message
        : 'No se pudo cargar la información de asistencias.';
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({
    required this.record,
    required this.user,
    required this.office,
    required this.onOpen,
  });

  final AttendanceRecord record;
  final UserProfile? user;
  final Office? office;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final completed = record.status == AttendanceStatus.completed;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          child: Icon(completed ? Icons.task_alt : Icons.pending_actions),
        ),
        title: Text(
          user?.fullName ?? record.userId,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user?.employeeCode ?? 'Usuario sin perfil visible'),
              Text(office?.name ?? record.officeId),
              Text(
                '${_formatDate(record.workDay.value)} · '
                '${record.status.label}',
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _AttendanceDetailDialog extends StatelessWidget {
  const _AttendanceDetailDialog({
    required this.record,
    required this.user,
    required this.office,
    required this.repository,
  });

  final AttendanceRecord record;
  final UserProfile? user;
  final Office? office;
  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Detalle de asistencia'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailRow(
                label: 'Trabajador',
                value: user?.fullName ?? record.userId,
              ),
              _DetailRow(
                label: 'Código',
                value: user?.employeeCode ?? 'No disponible',
              ),
              _DetailRow(label: 'Sede', value: office?.name ?? record.officeId),
              _DetailRow(
                label: 'Fecha',
                value: _formatDate(record.workDay.value),
              ),
              _DetailRow(label: 'Estado', value: record.status.label),
              const Divider(height: 28),
              _MarkDetail(
                title: 'Entrada',
                mark: record.checkIn,
                repository: repository,
              ),
              const SizedBox(height: 20),
              if (record.checkOut == null)
                const Text(
                  'La salida todavía no fue registrada.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                )
              else
                _MarkDetail(
                  title: 'Salida',
                  mark: record.checkOut!,
                  repository: repository,
                ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _MarkDetail extends StatelessWidget {
  const _MarkDetail({
    required this.title,
    required this.mark,
    required this.repository,
  });

  final String title;
  final AttendanceMark mark;
  final AdminRepository repository;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _DetailRow(label: 'Hora', value: _formatLimaTime(mark.recordedAt)),
            _DetailRow(
              label: 'Distancia',
              value: '${mark.distanceMeters.toStringAsFixed(1)} m',
            ),
            _DetailRow(
              label: 'Precisión',
              value: '${mark.accuracyMeters.toStringAsFixed(1)} m',
            ),
            _DetailRow(
              label: 'Coordenadas',
              value:
                  '${mark.latitude.toStringAsFixed(6)}, '
                  '${mark.longitude.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openEvidence(context),
              icon: const Icon(Icons.photo_camera_back_outlined),
              label: const Text('Ver evidencia fotográfica'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEvidence(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evidencia fotográfica'),
        content: SizedBox(
          width: 520,
          height: 480,
          child: FutureBuilder<String>(
            future: repository.getEvidenceDownloadUrl(
              evidencePath: mark.evidencePath,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;

                return _AttendanceMessage(
                  icon: Icons.broken_image_outlined,
                  message: error is AdminFailure
                      ? error.message
                      : 'No se pudo abrir la fotografía.',
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return InteractiveViewer(
                child: Image.network(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) {
                    return const _AttendanceMessage(
                      icon: Icons.broken_image_outlined,
                      message: 'La imagen no pudo descargarse.',
                    );
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _AttendanceMessage extends StatelessWidget {
  const _AttendanceMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String value) {
  final parts = value.split('-');

  if (parts.length != 3) {
    return value;
  }

  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _formatLimaTime(DateTime instant) {
  final lima = instant.toUtc().subtract(const Duration(hours: 5));
  final hour = lima.hour.toString().padLeft(2, '0');
  final minute = lima.minute.toString().padLeft(2, '0');
  final second = lima.second.toString().padLeft(2, '0');

  return '$hour:$minute:$second';
}
