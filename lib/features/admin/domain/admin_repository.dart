import '../../attendance/domain/attendance_record.dart';
import '../../offices/domain/office.dart';
import '../../users/domain/user_profile.dart';

class AdminUserCreateCommand {
  const AdminUserCreateCommand({
    required this.email,
    required this.temporaryPassword,
    required this.fullName,
    required this.employeeCode,
    required this.role,
    required this.status,
    required this.officeId,
  });

  final String email;
  final String temporaryPassword;
  final String fullName;
  final String employeeCode;
  final UserRole role;
  final UserStatus status;
  final String? officeId;
}

class AdminUserUpdateCommand {
  const AdminUserUpdateCommand({
    required this.uid,
    required this.fullName,
    required this.employeeCode,
    required this.role,
    required this.status,
    required this.officeId,
  });

  final String uid;
  final String fullName;
  final String employeeCode;
  final UserRole role;
  final UserStatus status;
  final String? officeId;
}

class AdminOfficeSaveCommand {
  const AdminOfficeSaveCommand({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.maxAccuracyMeters,
    required this.active,
    required this.isNew,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final double maxAccuracyMeters;
  final bool active;
  final bool isNew;
}

abstract interface class AdminRepository {
  Stream<List<UserProfile>> watchUsers({int limit = 100});

  Stream<List<Office>> watchOffices({int limit = 100});

  Stream<List<AttendanceRecord>> watchRecentAttendances({int limit = 50});

  Future<UserProfile> createUser({required AdminUserCreateCommand command});

  Future<void> updateUser({required AdminUserUpdateCommand command});

  Future<Office> saveOffice({required AdminOfficeSaveCommand command});

  Future<String> getEvidenceDownloadUrl({required String evidencePath});
}

class AdminFailure implements Exception {
  const AdminFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
