import 'dart:typed_data';

import 'package:control_asistencia/features/attendance/application/attendance_registration_service.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_day.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_record.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_repository.dart';
import 'package:control_asistencia/features/evidence/domain/attendance_evidence.dart';
import 'package:control_asistencia/features/evidence/domain/evidence_services.dart';
import 'package:control_asistencia/features/location/domain/device_location.dart';
import 'package:control_asistencia/features/location/domain/location_service.dart';
import 'package:control_asistencia/features/offices/domain/office.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = 'employee-001';

final _workDay = AttendanceDay.parse('2026-07-30');
final _now = DateTime.utc(2026, 7, 30, 15);

void main() {
  late _FakeAttendanceRepository attendanceRepository;
  late _FakeEvidenceRepository evidenceRepository;
  late _FakeEvidenceCamera evidenceCamera;
  late _FakeLocationService locationService;
  late AttendanceRegistrationService service;

  final office = _buildOffice();

  setUp(() {
    attendanceRepository = _FakeAttendanceRepository(
      checkInResult: _buildRecord(completed: false),
      checkOutResult: _buildRecord(completed: true),
    );

    evidenceRepository = _FakeEvidenceRepository();

    evidenceCamera = _FakeEvidenceCamera(capturedEvidence: _buildEvidence());

    locationService = _FakeLocationService(location: _buildLocation());

    service = AttendanceRegistrationService(
      attendanceRepository: attendanceRepository,
      evidenceRepository: evidenceRepository,
      evidenceCamera: evidenceCamera,
      locationService: locationService,
      clock: () => _now,
    );
  });

  test('registra entrada cuando no existe asistencia del día', () async {
    final result = await service.registerNextEvent(
      userId: _userId,
      office: office,
    );

    expect(result, isNotNull);
    expect(result!.event, EvidenceEvent.checkIn);
    expect(result.workDay, _workDay);
    expect(result.message, 'Entrada registrada correctamente.');

    expect(attendanceRepository.getCalls, 1);
    expect(attendanceRepository.checkInCalls, 1);
    expect(attendanceRepository.checkOutCalls, 0);
    expect(evidenceRepository.uploadCalls, 1);
    expect(locationService.getCalls, 1);
  });

  test('registra salida cuando existe una entrada abierta', () async {
    attendanceRepository.currentRecord = _buildRecord(completed: false);

    final result = await service.registerNextEvent(
      userId: _userId,
      office: office,
    );

    expect(result, isNotNull);
    expect(result!.event, EvidenceEvent.checkOut);
    expect(result.message, 'Salida registrada correctamente.');

    expect(attendanceRepository.checkInCalls, 0);
    expect(attendanceRepository.checkOutCalls, 1);
    expect(evidenceRepository.lastEvent, EvidenceEvent.checkOut);
  });

  test('cancela sin registrar cuando el usuario cierra la cámara', () async {
    evidenceCamera.capturedEvidence = null;

    final result = await service.registerNextEvent(
      userId: _userId,
      office: office,
    );

    expect(result, isNull);
    expect(locationService.getCalls, 0);
    expect(evidenceRepository.uploadCalls, 0);
    expect(attendanceRepository.checkInCalls, 0);
    expect(attendanceRepository.checkOutCalls, 0);
  });

  test('rechaza el registro cuando el GPS está fuera del radio', () async {
    locationService.location = _buildLocation(
      latitude: -12.784029,
      longitude: -74.971207,
    );

    await expectLater(
      service.registerNextEvent(userId: _userId, office: office),
      throwsA(
        isA<AttendanceFailure>().having(
          (failure) => failure.code,
          'code',
          AttendanceFailureCode.locationNotAllowed,
        ),
      ),
    );

    expect(evidenceRepository.uploadCalls, 0);
    expect(attendanceRepository.checkInCalls, 0);
  });

  test('elimina la foto cuando la transacción de Firestore falla', () async {
    attendanceRepository.registrationFailure = const AttendanceFailure(
      code: AttendanceFailureCode.duplicateCheckIn,
      message: 'La entrada ya existe.',
    );

    await expectLater(
      service.registerNextEvent(userId: _userId, office: office),
      throwsA(
        isA<AttendanceFailure>().having(
          (failure) => failure.code,
          'code',
          AttendanceFailureCode.duplicateCheckIn,
        ),
      ),
    );

    expect(evidenceRepository.uploadCalls, 1);
    expect(evidenceRepository.deletedPaths, hasLength(1));
    expect(
      evidenceRepository.deletedPaths.single,
      'attendanceEvidence/'
      'employee-001/'
      'employee-001_2026-07-30/'
      'check-in.jpg',
    );
  });

  test('impide registrar otra marca si la jornada terminó', () async {
    attendanceRepository.currentRecord = _buildRecord(completed: true);

    await expectLater(
      service.registerNextEvent(userId: _userId, office: office),
      throwsA(
        isA<AttendanceFailure>().having(
          (failure) => failure.code,
          'code',
          AttendanceFailureCode.alreadyCheckedOut,
        ),
      ),
    );

    expect(evidenceCamera.recoverCalls, 0);
    expect(evidenceCamera.captureCalls, 0);
    expect(evidenceRepository.uploadCalls, 0);
  });

  test('utiliza la fotografía recuperada sin abrir otra cámara', () async {
    evidenceCamera.recoveredEvidence = _buildEvidence();

    final result = await service.registerNextEvent(
      userId: _userId,
      office: office,
    );

    expect(result, isNotNull);
    expect(evidenceCamera.recoverCalls, 1);
    expect(evidenceCamera.captureCalls, 0);
    expect(evidenceRepository.uploadCalls, 1);
  });
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

DeviceLocation _buildLocation({
  double latitude = -12.389037,
  double longitude = -74.858949,
}) {
  return DeviceLocation(
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: 10,
    capturedAt: _now,
    isMocked: false,
  );
}

CapturedEvidence _buildEvidence() {
  return CapturedEvidence(
    bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]),
    capturedAt: _now,
  );
}

AttendanceMark _buildMark({required String fileName}) {
  return AttendanceMark(
    capturedAt: _now,
    recordedAt: _now,
    latitude: -12.389037,
    longitude: -74.858949,
    accuracyMeters: 10,
    distanceMeters: 0,
    isMocked: false,
    evidencePath:
        'attendanceEvidence/'
        'employee-001/'
        'employee-001_2026-07-30/'
        '$fileName',
  );
}

AttendanceRecord _buildRecord({required bool completed}) {
  return AttendanceRecord(
    id: 'employee-001_2026-07-30',
    userId: _userId,
    officeId: 'unh-pampas',
    workDay: _workDay,
    mode: AttendanceMode.onsite,
    status: completed ? AttendanceStatus.completed : AttendanceStatus.checkedIn,
    checkIn: _buildMark(fileName: 'check-in.jpg'),
    checkOut: completed ? _buildMark(fileName: 'check-out.jpg') : null,
    schemaVersion: 1,
    createdAt: _now,
    updatedAt: _now,
  );
}

final class _FakeAttendanceRepository implements AttendanceRepository {
  _FakeAttendanceRepository({
    required this.checkInResult,
    required this.checkOutResult,
  });

  AttendanceRecord? currentRecord;
  AttendanceRecord checkInResult;
  AttendanceRecord checkOutResult;
  AttendanceFailure? registrationFailure;

  int getCalls = 0;
  int checkInCalls = 0;
  int checkOutCalls = 0;

  @override
  Future<AttendanceRecord?> getForDay({
    required String userId,
    required AttendanceDay workDay,
  }) async {
    getCalls++;
    return currentRecord;
  }

  @override
  Future<AttendanceRecord> registerCheckIn({
    required AttendanceRegistrationCommand command,
  }) async {
    checkInCalls++;

    final failure = registrationFailure;

    if (failure != null) {
      throw failure;
    }

    return checkInResult;
  }

  @override
  Future<AttendanceRecord> registerCheckOut({
    required AttendanceRegistrationCommand command,
  }) async {
    checkOutCalls++;

    final failure = registrationFailure;

    if (failure != null) {
      throw failure;
    }

    return checkOutResult;
  }

  @override
  Stream<List<AttendanceRecord>> watchHistory({
    required String userId,
    int limit = 30,
  }) {
    return Stream<List<AttendanceRecord>>.value(
      currentRecord == null ? const [] : [currentRecord!],
    );
  }
}

final class _FakeEvidenceRepository implements EvidenceRepository {
  int uploadCalls = 0;
  EvidenceEvent? lastEvent;
  final List<String> deletedPaths = [];

  @override
  Future<String> upload({
    required String userId,
    required String officeId,
    required AttendanceDay workDay,
    required EvidenceEvent event,
    required CapturedEvidence evidence,
  }) async {
    uploadCalls++;
    lastEvent = event;

    return EvidencePolicy.pathFor(
      userId: userId,
      workDay: workDay,
      event: event,
    );
  }

  @override
  Future<void> deleteIfExists({required String path}) async {
    deletedPaths.add(path);
  }
}

final class _FakeEvidenceCamera implements EvidenceCamera {
  _FakeEvidenceCamera({required this.capturedEvidence});

  CapturedEvidence? capturedEvidence;
  CapturedEvidence? recoveredEvidence;

  int captureCalls = 0;
  int recoverCalls = 0;

  @override
  Future<CapturedEvidence?> capture() async {
    captureCalls++;
    return capturedEvidence;
  }

  @override
  Future<CapturedEvidence?> recoverLostCapture() async {
    recoverCalls++;
    return recoveredEvidence;
  }
}

final class _FakeLocationService implements LocationService {
  _FakeLocationService({required this.location});

  DeviceLocation location;
  int getCalls = 0;

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    getCalls++;
    return location;
  }

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> openLocationSettings() async => false;
}
