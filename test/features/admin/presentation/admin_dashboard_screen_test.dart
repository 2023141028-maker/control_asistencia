import 'package:control_asistencia/features/admin/domain/admin_repository.dart';
import 'package:control_asistencia/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_day.dart';
import 'package:control_asistencia/features/attendance/domain/attendance_record.dart';
import 'package:control_asistencia/features/auth/domain/auth_repository.dart';
import 'package:control_asistencia/features/offices/domain/office.dart';
import 'package:control_asistencia/features/users/domain/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<User?> authStateChanges() => const Stream.empty();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({
    required this.users,
    required this.offices,
    required this.attendances,
  });

  final List<UserProfile> users;
  final List<Office> offices;
  final List<AttendanceRecord> attendances;

  @override
  Future<UserProfile> createUser({required AdminUserCreateCommand command}) {
    throw UnimplementedError();
  }

  @override
  Future<String> getEvidenceDownloadUrl({required String evidencePath}) async {
    return 'https://example.com/evidence.jpg';
  }

  @override
  Future<Office> saveOffice({required AdminOfficeSaveCommand command}) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateUser({required AdminUserUpdateCommand command}) async {}

  @override
  Stream<List<AttendanceRecord>> watchRecentAttendances({int limit = 50}) {
    return Stream.value(attendances);
  }

  @override
  Stream<List<Office>> watchOffices({int limit = 100}) {
    return Stream.value(offices);
  }

  @override
  Stream<List<UserProfile>> watchUsers({int limit = 100}) {
    return Stream.value(users);
  }
}

void main() {
  final now = DateTime.utc(2026, 7, 30, 16);

  final admin = UserProfile(
    uid: 'admin-001',
    email: 'admin@unh.edu.pe',
    fullName: 'Administrador Demo',
    employeeCode: 'ADM-001',
    role: UserRole.admin,
    status: UserStatus.active,
    officeId: null,
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
  );

  final employee = UserProfile(
    uid: 'employee-001',
    email: 'employee@unh.edu.pe',
    fullName: 'Trabajador Demo',
    employeeCode: 'EMP-001',
    role: UserRole.employee,
    status: UserStatus.active,
    officeId: 'unh-pampas',
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
  );

  final office = Office(
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
    createdAt: now,
    updatedAt: now,
  );

  final mark = AttendanceMark(
    capturedAt: now,
    recordedAt: now,
    latitude: -12.389037,
    longitude: -74.858949,
    accuracyMeters: 5,
    distanceMeters: 0.1,
    isMocked: false,
    evidencePath:
        'attendanceEvidence/employee-001/'
        'employee-001_2026-07-30/check-in.jpg',
  );

  final attendance = AttendanceRecord(
    id: 'employee-001_2026-07-30',
    userId: employee.uid,
    officeId: office.id,
    workDay: AttendanceDay.parse('2026-07-30'),
    mode: AttendanceMode.onsite,
    status: AttendanceStatus.checkedIn,
    checkIn: mark,
    checkOut: null,
    schemaVersion: 1,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('administrador navega por todos los módulos', (tester) async {
    final repository = _FakeAdminRepository(
      users: [admin, employee],
      offices: [office],
      attendances: [attendance],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AdminDashboardScreen(
          profile: admin,
          authRepository: _FakeAuthRepository(),
          adminRepository: repository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Panel administrativo'), findsOneWidget);
    expect(find.text('Trabajadores activos'), findsOneWidget);

    await tester.tap(find.text('Personal'));
    await tester.pumpAndSettle();

    expect(find.text('Trabajador Demo'), findsOneWidget);
    expect(find.text('Nuevo'), findsOneWidget);

    await tester.tap(find.text('Sedes'));
    await tester.pumpAndSettle();

    expect(find.text('UNH sede Pampas'), findsOneWidget);
    expect(find.text('Nueva'), findsOneWidget);

    await tester.tap(find.text('Asistencias'));
    await tester.pumpAndSettle();

    expect(find.text('Trabajador Demo'), findsOneWidget);
    expect(find.textContaining('Entrada registrada'), findsOneWidget);
  });
}
