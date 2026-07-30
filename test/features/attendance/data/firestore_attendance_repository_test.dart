import 'package:control_asistencia/features/attendance/data/firestore_attendance_repository.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_day.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_record.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_repository.dart';
import 'package:control_asistencia/features/location/domain/device_location.dart';
import 'package:control_asistencia/features/offices/domain/office.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = 'user-123';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreAttendanceRepository repository;
  late Office office;

  setUp(() {
    firestore = FakeFirebaseFirestore();

    repository = FirestoreAttendanceRepository(firestore: firestore);

    office = _buildOffice();
  });

  test('registra entrada y rechaza una entrada duplicada', () async {
    final checkInCommand = _buildCommand(office: office, eventName: 'check-in');

    final record = await repository.registerCheckIn(command: checkInCommand);

    expect(record.status, AttendanceStatus.checkedIn);
    expect(record.checkOut, isNull);

    await expectLater(
      repository.registerCheckIn(command: checkInCommand),
      throwsA(
        isA<AttendanceFailure>().having(
          (failure) => failure.code,
          'code',
          AttendanceFailureCode.duplicateCheckIn,
        ),
      ),
    );
  });

  test('rechaza una salida cuando no existe entrada', () async {
    final checkOutCommand = _buildCommand(
      office: office,
      eventName: 'check-out',
    );

    await expectLater(
      repository.registerCheckOut(command: checkOutCommand),
      throwsA(
        isA<AttendanceFailure>().having(
          (failure) => failure.code,
          'code',
          AttendanceFailureCode.missingCheckIn,
        ),
      ),
    );
  });

  test('completa la jornada después de registrar entrada', () async {
    await repository.registerCheckIn(
      command: _buildCommand(office: office, eventName: 'check-in'),
    );

    final completedRecord = await repository.registerCheckOut(
      command: _buildCommand(office: office, eventName: 'check-out'),
    );

    expect(completedRecord.status, AttendanceStatus.completed);
    expect(completedRecord.checkOut, isNotNull);
    expect(completedRecord.hasCompletedDay, isTrue);
  });

  test('rechaza una salida duplicada', () async {
    await repository.registerCheckIn(
      command: _buildCommand(office: office, eventName: 'check-in'),
    );

    final checkOutCommand = _buildCommand(
      office: office,
      eventName: 'check-out',
    );

    await repository.registerCheckOut(command: checkOutCommand);

    await expectLater(
      repository.registerCheckOut(command: checkOutCommand),
      throwsA(
        isA<AttendanceFailure>().having(
          (failure) => failure.code,
          'code',
          AttendanceFailureCode.alreadyCheckedOut,
        ),
      ),
    );
  });
}

AttendanceRegistrationCommand _buildCommand({
  required Office office,
  required String eventName,
}) {
  final workDay = AttendanceDay.parse('2026-07-30');
  final attendanceId = workDay.documentIdFor(_userId);

  return AttendanceRegistrationCommand(
    userId: _userId,
    office: office,
    workDay: workDay,
    location: DeviceLocation(
      latitude: office.latitude,
      longitude: office.longitude,
      accuracyMeters: 5,
      capturedAt: DateTime.now().toUtc(),
      isMocked: false,
    ),
    evidencePath:
        'attendanceEvidence/'
        '$_userId/'
        '$attendanceId/'
        '$eventName.jpg',
  );
}

Office _buildOffice() {
  return Office(
    id: 'unh-pampas',
    name: 'UNH sede Pampas',
    address: 'Av. Perú, Daniel Hernández 09161',
    latitude: -12.389037,
    longitude: -74.858949,
    radiusMeters: 100,
    maxAccuracyMeters: 30,
    timezone: 'America/Lima',
    active: true,
    schemaVersion: 1,
    createdAt: DateTime.utc(2026, 7, 29),
    updatedAt: DateTime.utc(2026, 7, 29),
  );
}
