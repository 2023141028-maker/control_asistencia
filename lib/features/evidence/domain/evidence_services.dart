import '../../attendance/domain/attendance_day.dart';
import 'attendance_evidence.dart';

abstract interface class EvidenceCamera {
  Future<CapturedEvidence?> capture();

  Future<CapturedEvidence?> recoverLostCapture();
}

abstract interface class EvidenceRepository {
  Future<String> upload({
    required String userId,
    required String officeId,
    required AttendanceDay workDay,
    required EvidenceEvent event,
    required CapturedEvidence evidence,
  });

  Future<void> deleteIfExists({required String path});
}
