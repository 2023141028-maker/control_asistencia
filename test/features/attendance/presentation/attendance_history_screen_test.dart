import 'package:control_asistencia/features/attendance/domain/attendance_day.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_record.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_repository.dart';
import 'package:control_asistencia/features/attendance/presentation/attendance_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  FakeAttendanceRepository({required this.historyStream});

  final Stream<List<AttendanceRecord>> historyStream;

  @override
  Stream<List<AttendanceRecord>> watchHistory({
    required String userId,
    int limit = 30,
  }) {
    return historyStream;
  }

  @override
  Future<AttendanceRecord?> getForDay({
    required String userId,
    required AttendanceDay workDay,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AttendanceRecord> registerCheckIn({
    required AttendanceRegistrationCommand command,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AttendanceRecord> registerCheckOut({
    required AttendanceRegistrationCommand command,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('muestra un estado vacío cuando no existen asistencias', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository(
      historyStream: Stream<List<AttendanceRecord>>.value(
        const <AttendanceRecord>[],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceHistoryScreen(
          userId: 'employee-001',
          attendanceRepository: repository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Historial de asistencias'), findsOneWidget);
    expect(find.text('Sin asistencias'), findsOneWidget);
    expect(find.text('Aún no tienes asistencias registradas.'), findsOneWidget);
  });

  testWidgets('muestra una jornada con entrada pendiente de salida', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository(
      historyStream: Stream<List<AttendanceRecord>>.value([
        _attendanceRecord(completed: false),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceHistoryScreen(
          userId: 'employee-001',
          attendanceRepository: repository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('attendance-history-list')), findsOneWidget);
    expect(find.text('30/07/2026'), findsOneWidget);
    expect(find.text('Entrada registrada'), findsOneWidget);
    expect(find.text('Salida pendiente'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
  });

  testWidgets('muestra una jornada completada con entrada y salida', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository(
      historyStream: Stream<List<AttendanceRecord>>.value([
        _attendanceRecord(completed: true),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceHistoryScreen(
          userId: 'employee-001',
          attendanceRepository: repository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Jornada completada'), findsOneWidget);
    expect(find.text('Entrada'), findsOneWidget);
    expect(find.text('Salida'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);
    expect(find.text('0.1 m'), findsNWidgets(2));
    expect(find.text('5.0 m'), findsNWidgets(2));
  });

  testWidgets('muestra el error del repositorio y permite reintentar', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository(
      historyStream: Stream<List<AttendanceRecord>>.error(
        const AttendanceFailure(
          code: AttendanceFailureCode.permissionDenied,
          message: 'No tienes permiso para consultar el historial.',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceHistoryScreen(
          userId: 'employee-001',
          attendanceRepository: repository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el historial'), findsOneWidget);
    expect(
      find.text('No tienes permiso para consultar el historial.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

AttendanceRecord _attendanceRecord({required bool completed}) {
  final checkInTime = DateTime.utc(2026, 7, 30, 13);
  final checkOutTime = DateTime.utc(2026, 7, 30, 22);

  return AttendanceRecord(
    id: 'employee-001_2026-07-30',
    userId: 'employee-001',
    officeId: 'unh-pampas',
    workDay: AttendanceDay.parse('2026-07-30'),
    mode: AttendanceMode.onsite,
    status: completed ? AttendanceStatus.completed : AttendanceStatus.checkedIn,
    checkIn: AttendanceMark(
      capturedAt: checkInTime,
      recordedAt: checkInTime,
      latitude: -12.389037,
      longitude: -74.858949,
      accuracyMeters: 5,
      distanceMeters: 0.1,
      isMocked: false,
      evidencePath:
          'attendanceEvidence/employee-001/'
          'employee-001_2026-07-30/check-in.jpg',
    ),
    checkOut: completed
        ? AttendanceMark(
            capturedAt: checkOutTime,
            recordedAt: checkOutTime,
            latitude: -12.389037,
            longitude: -74.858949,
            accuracyMeters: 5,
            distanceMeters: 0.1,
            isMocked: false,
            evidencePath:
                'attendanceEvidence/employee-001/'
                'employee-001_2026-07-30/check-out.jpg',
          )
        : null,
    schemaVersion: 1,
    createdAt: checkInTime,
    updatedAt: completed ? checkOutTime : checkInTime,
  );
}
