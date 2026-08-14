import 'package:control_asistencia/features/attendance/domain/attendance_day.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_receipt.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_record.dart';
import 'package:control_asistencia/features/evidence/domain/attendance_evidence.dart';
import 'package:control_asistencia/features/offices/domain/office.dart';
import 'package:control_asistencia/features/users/domain/hospital_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('genera una constancia estable y oculta el nombre', () {
    final recordedAt = DateTime.utc(2026, 8, 9, 13, 5, 10);
    final mark = AttendanceMark(
      capturedAt: recordedAt,
      recordedAt: recordedAt,
      latitude: -12.389,
      longitude: -74.858,
      accuracyMeters: 8,
      distanceMeters: 14.5,
      isMocked: false,
      evidencePath:
          'https://res.cloudinary.com/demo/image/upload/v1/'
          'attendanceEvidence/user-1/user-1_2026-08-09/check-in.jpg',
    );
    final record = AttendanceRecord(
      id: 'user-1_2026-08-09',
      userId: 'user-1',
      officeId: 'office-1',
      workDay: AttendanceDay.parse('2026-08-09'),
      mode: AttendanceMode.onsite,
      status: AttendanceStatus.checkedIn,
      checkIn: mark,
      checkOut: null,
      schemaVersion: 1,
      createdAt: recordedAt,
      updatedAt: recordedAt,
    );
    final office = Office(
      id: 'office-1',
      name: 'Sede de demostración',
      address: 'Dirección de demostración',
      latitude: -12.389,
      longitude: -74.858,
      radiusMeters: 100,
      maxAccuracyMeters: 30,
      timezone: 'America/Lima',
      active: true,
      schemaVersion: 1,
      createdAt: recordedAt,
      updatedAt: recordedAt,
    );

    final receipt = AttendanceReceipt.fromRegistration(
      record: record,
      event: EvidenceEvent.checkIn,
      employeeCode: 'EMP-DEMO',
      employeeName: 'Usuario De Prueba',
      office: office,
      hospitalArea: HospitalArea.emergency,
      position: 'Enfermero asistencial',
      shift: HospitalShift.night,
    );

    expect(receipt.number, startsWith('ASI-20260809-ENT-'));
    expect(receipt.maskedEmployeeName, 'U****** D* P*****');
    expect(receipt.verificationCode, hasLength(8));
    expect(receipt.taxLegend, contains('Impuesto no aplicable'));
    expect(receipt.hospitalArea, 'Emergencia');
    expect(receipt.position, 'Enfermero asistencial');
    expect(receipt.shift, contains('Noche'));
  });
}
