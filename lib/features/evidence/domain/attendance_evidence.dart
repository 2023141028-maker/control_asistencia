import 'dart:typed_data';

import '../../attendance/domain/attendance_day.dart';

enum EvidenceEvent { checkIn, checkOut }

extension EvidenceEventDetails on EvidenceEvent {
  String get value => switch (this) {
    EvidenceEvent.checkIn => 'check-in',
    EvidenceEvent.checkOut => 'check-out',
  };

  String get fileName => '$value.jpg';
}

final class CapturedEvidence {
  const CapturedEvidence({required this.bytes, required this.capturedAt});

  final Uint8List bytes;
  final DateTime capturedAt;

  int get sizeBytes => bytes.lengthInBytes;
}

enum EvidenceFailureCode {
  cameraPermissionDenied,
  captureFailed,
  emptyFile,
  invalidFormat,
  fileTooLarge,
  invalidData,
  unauthenticated,
  permissionDenied,
  unavailable,
}

class EvidenceFailure implements Exception {
  const EvidenceFailure({required this.code, required this.message});

  final EvidenceFailureCode code;
  final String message;

  @override
  String toString() => message;
}

final class EvidencePolicy {
  EvidencePolicy._();

  static const int maxSizeBytes = 2 * 1024 * 1024;

  static String pathFor({
    required String userId,
    required AttendanceDay workDay,
    required EvidenceEvent event,
  }) {
    final normalizedUserId = validateUserId(userId);
    final attendanceId = workDay.documentIdFor(normalizedUserId);

    return 'attendanceEvidence/'
        '$normalizedUserId/'
        '$attendanceId/'
        '${event.fileName}';
  }

  static String validateUserId(String userId) {
    final normalized = userId.trim();

    if (normalized.isEmpty ||
        normalized != userId ||
        normalized.contains('/') ||
        normalized.length > 128) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.invalidData,
        message: 'El UID de la evidencia no es válido.',
      );
    }

    return normalized;
  }

  static String validateOfficeId(String officeId) {
    final normalized = officeId.trim();

    if (normalized.length < 3 ||
        normalized.length > 50 ||
        normalized != officeId ||
        normalized.contains('/')) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.invalidData,
        message: 'La sede de la evidencia no es válida.',
      );
    }

    return normalized;
  }

  static void validateCapturedEvidence(CapturedEvidence evidence) {
    if (evidence.bytes.isEmpty) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.emptyFile,
        message: 'La fotografía está vacía.',
      );
    }

    if (evidence.sizeBytes > maxSizeBytes) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.fileTooLarge,
        message: 'La fotografía no puede superar los 2 MB.',
      );
    }

    if (!_hasJpegSignature(evidence.bytes)) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.invalidFormat,
        message: 'La evidencia debe ser una fotografía JPEG válida.',
      );
    }
  }

  static bool _hasJpegSignature(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }
}
