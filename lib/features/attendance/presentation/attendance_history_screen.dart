import 'package:flutter/material.dart';

import '../domain/attendance_record.dart';
import '../domain/attendance_repository.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({
    required this.userId,
    required this.attendanceRepository,
    super.key,
  });

  final String userId;
  final AttendanceRepository attendanceRepository;

  @override
  State<AttendanceHistoryScreen> createState() {
    return _AttendanceHistoryScreenState();
  }
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late Stream<List<AttendanceRecord>> _historyStream;

  @override
  void initState() {
    super.initState();
    _historyStream = _watchHistory();
  }

  @override
  void didUpdateWidget(covariant AttendanceHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId ||
        oldWidget.attendanceRepository != widget.attendanceRepository) {
      _historyStream = _watchHistory();
    }
  }

  Stream<List<AttendanceRecord>> _watchHistory() {
    return widget.attendanceRepository.watchHistory(
      userId: widget.userId,
      limit: 30,
    );
  }

  void _retry() {
    setState(() {
      _historyStream = _watchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de asistencias')),
      body: SafeArea(
        child: StreamBuilder<List<AttendanceRecord>>(
          stream: _historyStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const _LoadingHistory();
            }

            if (snapshot.hasError) {
              final error = snapshot.error;

              final message = error is AttendanceFailure
                  ? error.message
                  : 'No se pudo cargar el historial de asistencias.';

              return _HistoryError(message: message, onRetry: _retry);
            }

            final records = snapshot.data ?? const <AttendanceRecord>[];

            if (records.isEmpty) {
              return const _EmptyHistory();
            }

            return ListView.separated(
              key: const Key('attendance-history-list'),
              padding: const EdgeInsets.all(20),
              itemCount: records.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _AttendanceHistoryCard(record: records[index]),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AttendanceHistoryCard extends StatelessWidget {
  const _AttendanceHistoryCard({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completed = record.status == AttendanceStatus.completed;

    final statusColor = completed
        ? colors.primaryContainer
        : colors.tertiaryContainer;

    final statusForeground = completed
        ? colors.onPrimaryContainer
        : colors.onTertiaryContainer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  completed ? Icons.task_alt : Icons.pending_actions_outlined,
                  color: colors.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatWorkDate(record.workDay.value),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Sede: ${record.officeId}'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.status.label,
                    style: TextStyle(
                      color: statusForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            _MarkSection(
              title: 'Entrada',
              icon: Icons.login,
              mark: record.checkIn,
            ),
            const SizedBox(height: 16),
            if (record.checkOut == null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: colors.onTertiaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Salida pendiente',
                        style: TextStyle(
                          color: colors.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              _MarkSection(
                title: 'Salida',
                icon: Icons.logout,
                mark: record.checkOut!,
              ),
          ],
        ),
      ),
    );
  }
}

class _MarkSection extends StatelessWidget {
  const _MarkSection({
    required this.title,
    required this.icon,
    required this.mark,
  });

  final String title;
  final IconData icon;
  final AttendanceMark mark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 21, color: colors.primary),
            const SizedBox(width: 9),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        _HistoryMetric(
          label: 'Hora registrada',
          value: _formatLimaTime(mark.recordedAt),
        ),
        const SizedBox(height: 6),
        _HistoryMetric(
          label: 'Distancia',
          value: '${mark.distanceMeters.toStringAsFixed(1)} m',
        ),
        const SizedBox(height: 6),
        _HistoryMetric(
          label: 'Precisión',
          value: '${mark.accuracyMeters.toStringAsFixed(1)} m',
        ),
      ],
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.end,
        ),
      ],
    );
  }
}

class _LoadingHistory extends StatelessWidget {
  const _LoadingHistory();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Consultando historial...'),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_toggle_off, size: 72, color: colors.primary),
              const SizedBox(height: 18),
              Text(
                'Sin asistencias',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'Aún no tienes asistencias registradas.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: colors.error),
              const SizedBox(height: 18),
              Text(
                'No se pudo cargar el historial',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatWorkDate(String value) {
  final parts = value.split('-');

  if (parts.length != 3) {
    return value;
  }

  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String _formatLimaTime(DateTime value) {
  final limaTime = value.toUtc().subtract(const Duration(hours: 5));

  final hour = limaTime.hour.toString().padLeft(2, '0');
  final minute = limaTime.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}
