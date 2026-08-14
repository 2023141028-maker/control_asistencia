import '../../evidence/domain/attendance_evidence.dart';
import '../../offices/domain/office.dart';
import 'attendance_record.dart';
import '../../users/domain/hospital_assignment.dart';

final class AttendanceReceipt {
  const AttendanceReceipt({
    required this.number,
    required this.verificationCode,
    required this.employeeCode,
    required this.maskedEmployeeName,
    required this.event,
    required this.recordedAt,
    required this.officeName,
    required this.distanceMeters,
    required this.privacyConsentVersion,
    required this.evidenceRetentionUntil,
    required this.hospitalArea,
    required this.position,
    required this.shift,
  });

  factory AttendanceReceipt.fromRegistration({
    required AttendanceRecord record,
    required EvidenceEvent event,
    required String employeeCode,
    required String employeeName,
    required Office office,
    HospitalArea hospitalArea = HospitalArea.administration,
    String position = 'Trabajador',
    HospitalShift shift = HospitalShift.morning,
  }) {
    final mark = event == EvidenceEvent.checkIn
        ? record.checkIn
        : record.checkOut!;
    final eventCode = event == EvidenceEvent.checkIn ? 'ENT' : 'SAL';
    final date = record.workDay.value.replaceAll('-', '');
    final stablePayload =
        '${record.id}|${event.value}|${mark.recordedAt.toUtc().toIso8601String()}';
    final verificationCode = _fnv1a(stablePayload)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');

    return AttendanceReceipt(
      number: 'ASI-$date-$eventCode-${verificationCode.substring(0, 6)}',
      verificationCode: verificationCode,
      employeeCode: employeeCode,
      maskedEmployeeName: _maskName(employeeName),
      event: event,
      recordedAt: mark.recordedAt,
      officeName: office.name,
      distanceMeters: mark.distanceMeters,
      privacyConsentVersion: mark.privacyConsentVersion,
      evidenceRetentionUntil: mark.evidenceRetentionUntil,
      hospitalArea: hospitalArea.label,
      position: position,
      shift: shift.label,
    );
  }

  final String number;
  final String verificationCode;
  final String employeeCode;
  final String maskedEmployeeName;
  final EvidenceEvent event;
  final DateTime recordedAt;
  final String officeName;
  final double distanceMeters;
  final String? privacyConsentVersion;
  final DateTime? evidenceRetentionUntil;
  final String hospitalArea;
  final String position;
  final String shift;

  String get eventLabel =>
      event == EvidenceEvent.checkIn ? 'Entrada' : 'Salida';

  String get taxLegend =>
      'Constancia laboral sin importe. Impuesto no aplicable.';

  static String _maskName(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
          if (part.length == 1) return '${part[0]}*';
          final hidden = List.filled(part.length - 1, '*').join();
          return '${part[0]}$hidden';
        })
        .join(' ');
  }

  static int _fnv1a(String value) {
    var hash = 0x811C9DC5;
    for (final byte in value.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
