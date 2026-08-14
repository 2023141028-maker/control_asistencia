import '../../location/domain/device_location.dart';
import '../../offices/domain/office.dart';
import 'attendance_day.dart';
import 'attendance_record.dart';

class AttendanceRegistrationCommand {
  const AttendanceRegistrationCommand({
    required this.userId,
    required this.office,
    required this.workDay,
    required this.location,
    required this.evidencePath,
    required this.privacyConsentAccepted,
    required this.privacyConsentVersion,
    required this.evidenceRetentionUntil,
    this.faceSimilarity,
    this.livenessVerified = false,
    this.livenessChallenge,
  });

  final String userId;
  final Office office;
  final AttendanceDay workDay;
  final DeviceLocation location;
  final String evidencePath;
  final bool privacyConsentAccepted;
  final String privacyConsentVersion;
  final DateTime evidenceRetentionUntil;
  final double? faceSimilarity;
  final bool livenessVerified;
  final String? livenessChallenge;
}

abstract interface class AttendanceRepository {
  Future<AttendanceRecord?> getForDay({
    required String userId,
    required AttendanceDay workDay,
  });

  Stream<List<AttendanceRecord>> watchHistory({
    required String userId,
    int limit = 30,
  });

  Future<AttendanceRecord> registerCheckIn({
    required AttendanceRegistrationCommand command,
  });

  Future<AttendanceRecord> registerCheckOut({
    required AttendanceRegistrationCommand command,
  });
}

enum AttendanceFailureCode {
  duplicateCheckIn,
  missingCheckIn,
  alreadyCheckedOut,
  locationNotAllowed,
  evidenceRequired,
  privacyConsentRequired,
  permissionDenied,
  unavailable,
  invalidData,
}

class AttendanceFailure implements Exception {
  const AttendanceFailure({required this.code, required this.message});

  final AttendanceFailureCode code;
  final String message;

  @override
  String toString() => message;
}
