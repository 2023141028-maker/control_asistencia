enum UserRole { admin, employee }

enum UserStatus { active, inactive, pending }

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.employeeCode,
    required this.role,
    required this.status,
    required this.officeId,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String email;
  final String fullName;
  final String employeeCode;
  final UserRole role;
  final UserStatus status;
  final String? officeId;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => status == UserStatus.active;
  bool get isAdmin => role == UserRole.admin;
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Administrador',
    UserRole.employee => 'Trabajador',
  };
}

extension UserStatusLabel on UserStatus {
  String get label => switch (this) {
    UserStatus.active => 'Activo',
    UserStatus.inactive => 'Inactivo',
    UserStatus.pending => 'Pendiente',
  };
}
