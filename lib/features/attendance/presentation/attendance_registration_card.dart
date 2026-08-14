import 'package:flutter/material.dart';

import '../../evidence/domain/attendance_evidence.dart';
import '../../face_verification/domain/face_profile.dart';
import '../../location/domain/location_service.dart';
import '../../offices/domain/office.dart';
import '../../privacy/domain/privacy_policy.dart';
import '../application/attendance_registration_service.dart';
import '../domain/attendance_day.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_receipt.dart';
import '../domain/attendance_repository.dart';
import '../../users/domain/hospital_assignment.dart';

class AttendanceRegistrationCard extends StatefulWidget {
  const AttendanceRegistrationCard({
    required this.userId,
    required this.employeeCode,
    required this.employeeName,
    required this.hospitalArea,
    required this.position,
    required this.shift,
    required this.office,
    required this.attendanceRepository,
    required this.registrationService,
    super.key,
  });

  final String userId;
  final String employeeCode;
  final String employeeName;
  final HospitalArea hospitalArea;
  final String position;
  final HospitalShift shift;
  final Office office;
  final AttendanceRepository attendanceRepository;
  final AttendanceRegistrationService registrationService;

  @override
  State<AttendanceRegistrationCard> createState() {
    return _AttendanceRegistrationCardState();
  }
}

class _AttendanceRegistrationCardState
    extends State<AttendanceRegistrationCard> {
  late Future<AttendanceRecord?> _recordFuture;
  bool _isRegistering = false;

  AttendanceDay get _today {
    return AttendanceDay.forShift(DateTime.now(), widget.shift);
  }

  @override
  void initState() {
    super.initState();
    _recordFuture = _loadRecord();
  }

  @override
  void didUpdateWidget(covariant AttendanceRegistrationCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId ||
        oldWidget.office.id != widget.office.id ||
        oldWidget.shift != widget.shift ||
        oldWidget.attendanceRepository != widget.attendanceRepository) {
      _recordFuture = _loadRecord();
    }
  }

  Future<AttendanceRecord?> _loadRecord() {
    return widget.attendanceRepository.getForDay(
      userId: widget.userId,
      workDay: _today,
    );
  }

  void _reload() {
    setState(() {
      _recordFuture = _loadRecord();
    });
  }

  Future<void> _register(AttendanceRecord? currentRecord) async {
    final event = currentRecord == null
        ? EvidenceEvent.checkIn
        : EvidenceEvent.checkOut;

    final confirmed = await _confirmRegistration(event);

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      final result = await widget.registrationService.registerNextEvent(
        userId: widget.userId,
        office: widget.office,
        privacyConsentAccepted: true,
        shift: widget.shift,
      );

      if (!mounted) {
        return;
      }

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La captura fotográfica fue cancelada.'),
          ),
        );
        return;
      }

      setState(() {
        _recordFuture = _loadRecord();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));

      final receipt = AttendanceReceipt.fromRegistration(
        record: result.record,
        event: result.event,
        employeeCode: widget.employeeCode,
        employeeName: widget.employeeName,
        office: widget.office,
        hospitalArea: widget.hospitalArea,
        position: widget.position,
        shift: widget.shift,
      );

      await _showReceipt(receipt);
    } on AttendanceFailure catch (error) {
      _showError(error.message);
    } on EvidenceFailure catch (error) {
      _showError(error.message);
    } on FaceVerificationFailure catch (error) {
      _showError(error.message);
    } on LocationFailure catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('No se pudo completar el registro de asistencia.');
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  Future<void> _showReceipt(AttendanceReceipt receipt) {
    final limaTime = receipt.recordedAt.toUtc().subtract(
      const Duration(hours: 5),
    );
    final date =
        '${limaTime.day.toString().padLeft(2, '0')}/'
        '${limaTime.month.toString().padLeft(2, '0')}/${limaTime.year}';
    final time =
        '${limaTime.hour.toString().padLeft(2, '0')}:'
        '${limaTime.minute.toString().padLeft(2, '0')}:'
        '${limaTime.second.toString().padLeft(2, '0')}';

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Constancia de asistencia'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReceiptRow(label: 'N.º', value: receipt.number),
              _ReceiptRow(label: 'Trabajador', value: receipt.maskedEmployeeName),
              _ReceiptRow(label: 'Código', value: receipt.employeeCode),
              _ReceiptRow(label: 'Evento', value: receipt.eventLabel),
              _ReceiptRow(label: 'Fecha', value: date),
              _ReceiptRow(label: 'Hora', value: time),
              _ReceiptRow(label: 'Sede', value: receipt.officeName),
              _ReceiptRow(label: 'Área', value: receipt.hospitalArea),
              _ReceiptRow(label: 'Cargo', value: receipt.position),
              _ReceiptRow(label: 'Turno', value: receipt.shift),
              _ReceiptRow(
                label: 'Ubicación',
                value:
                    'Validada (${receipt.distanceMeters.toStringAsFixed(1)} m)',
              ),
              _ReceiptRow(
                label: 'Verificación',
                value: receipt.verificationCode,
              ),
              if (receipt.privacyConsentVersion != null)
                _ReceiptRow(
                  label: 'Privacidad',
                  value: 'Aviso v${receipt.privacyConsentVersion}',
                ),
              if (receipt.evidenceRetentionUntil != null)
                _ReceiptRow(
                  label: 'Evidencia hasta',
                  value: _formatDate(receipt.evidenceRetentionUntil!),
                ),
              const Divider(height: 28),
              Text(
                receipt.taxLegend,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final limaTime = value.toUtc().subtract(const Duration(hours: 5));
    return '${limaTime.day.toString().padLeft(2, '0')}/'
        '${limaTime.month.toString().padLeft(2, '0')}/${limaTime.year}';
  }

  Future<bool> _confirmRegistration(EvidenceEvent event) async {
    final action = switch (event) {
      EvidenceEvent.checkIn => 'registrar tu entrada',
      EvidenceEvent.checkOut => 'registrar tu salida',
    };

    var consentAccepted = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Confirmar asistencia'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Para $action se tomará una fotografía frontal, se '
                    'comparará la plantilla facial y se obtendrá una '
                    'ubicación GPS nueva.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Finalidad: verificar identidad y presencia. La evidencia '
                    'tendrá una conservación programada de '
                    '${PrivacyPolicy.evidenceRetentionDays} días.',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aviso de privacidad v${PrivacyPolicy.noticeVersion}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: consentAccepted,
                    onChanged: (value) {
                      setDialogState(() {
                        consentAccepted = value ?? false;
                      });
                    },
                    title: const Text(
                      'He leído y autorizo este tratamiento para registrar '
                      'esta marcación.',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: consentAccepted
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Continuar'),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<AttendanceRecord?>(
          future: _recordFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingAttendance();
            }

            if (snapshot.hasError) {
              final error = snapshot.error;

              final message = error is AttendanceFailure
                  ? error.message
                  : 'No se pudo consultar la asistencia de hoy.';

              return _AttendanceError(message: message, onRetry: _reload);
            }

            final record = snapshot.data;
            final completed = record?.hasCompletedDay ?? false;
            final hasCheckIn = record?.status == AttendanceStatus.checkedIn;

            final title = switch ((record, completed)) {
              (null, _) => 'Entrada pendiente',
              (_, true) => 'Jornada completada',
              _ => 'Salida pendiente',
            };

            final description = switch ((record, completed)) {
              (null, _) => 'Todavía no registraste tu entrada de hoy.',
              (_, true) => 'La entrada y la salida fueron registradas.',
              _ => 'Tu entrada fue registrada. Falta registrar la salida.',
            };

            final icon = switch ((record, completed)) {
              (null, _) => Icons.login,
              (_, true) => Icons.task_alt,
              _ => Icons.logout,
            };

            final containerColor = completed
                ? colors.primaryContainer
                : hasCheckIn
                ? colors.tertiaryContainer
                : colors.secondaryContainer;

            final foregroundColor = completed
                ? colors.onPrimaryContainer
                : hasCheckIn
                ? colors.onTertiaryContainer
                : colors.onSecondaryContainer;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.fact_check_outlined, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Registro de asistencia',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Fecha laboral: ${_today.value}'),
                Text('Turno asignado: ${widget.shift.label}'),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: foregroundColor, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: foregroundColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: TextStyle(color: foregroundColor),
                            ),
                            if (record != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Entrada: '
                                '${_formatLimaTime(record.checkIn.recordedAt)}',
                                style: TextStyle(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (record?.checkOut != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Salida: '
                                '${_formatLimaTime(record!.checkOut!.recordedAt)}',
                                style: TextStyle(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: completed || _isRegistering
                      ? null
                      : () => _register(record),
                  icon: _isRegistering
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(record == null ? Icons.login : Icons.logout),
                  label: Text(
                    _isRegistering
                        ? 'Procesando...'
                        : completed
                        ? 'Jornada completada'
                        : record == null
                        ? 'Registrar entrada'
                        : 'Registrar salida',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'La operación requiere conexión, GPS preciso y fotografía '
                  'JPEG. No se admiten registros duplicados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatLimaTime(DateTime value) {
    final limaTime = value.toUtc().subtract(const Duration(hours: 5));

    final hour = limaTime.hour.toString().padLeft(2, '0');
    final minute = limaTime.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

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
            width: 95,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _LoadingAttendance extends StatelessWidget {
  const _LoadingAttendance();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 14),
          Text('Consultando la asistencia de hoy...'),
        ],
      ),
    );
  }
}

class _AttendanceError extends StatelessWidget {
  const _AttendanceError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(Icons.cloud_off, color: colors.error, size: 44),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}
