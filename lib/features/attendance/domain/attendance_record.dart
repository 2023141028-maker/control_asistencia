import 'attendance_day.dart';

enum AttendanceMode { onsite }

extension AttendanceModeDetails on AttendanceMode {
  String get value => switch (this) {
    AttendanceMode.onsite => 'onsite',
  };

  String get label => switch (this) {
    AttendanceMode.onsite => 'Presencial',
  };
}

enum AttendanceStatus { checkedIn, completed }

extension AttendanceStatusDetails on AttendanceStatus {
  String get value => switch (this) {
    AttendanceStatus.checkedIn => 'checked-in',
    AttendanceStatus.completed => 'completed',
  };

  String get label => switch (this) {
    AttendanceStatus.checkedIn => 'Entrada registrada',
    AttendanceStatus.completed => 'Jornada completada',
  };
}

class AttendanceMark {
  const AttendanceMark({
    required this.capturedAt,
    required this.recordedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.distanceMeters,
    required this.isMocked,
    required this.evidencePath,
  });

  final DateTime capturedAt;
  final DateTime recordedAt;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double distanceMeters;
  final bool isMocked;
  final String evidencePath;
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.userId,
    required this.officeId,
    required this.workDay,
    required this.mode,
    required this.status,
    required this.checkIn,
    required this.checkOut,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String officeId;
  final AttendanceDay workDay;
  final AttendanceMode mode;
  final AttendanceStatus status;
  final AttendanceMark checkIn;
  final AttendanceMark? checkOut;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasCompletedDay {
    return status == AttendanceStatus.completed && checkOut != null;
  }
}
