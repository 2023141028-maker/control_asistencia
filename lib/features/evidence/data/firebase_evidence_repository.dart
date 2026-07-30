import 'package:firebase_storage/firebase_storage.dart';

import '../../attendance/domain/attendance_day.dart';
import '../domain/attendance_evidence.dart';
import '../domain/evidence_services.dart';

final class FirebaseEvidenceRepository implements EvidenceRepository {
  FirebaseEvidenceRepository({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> upload({
    required String userId,
    required String officeId,
    required AttendanceDay workDay,
    required EvidenceEvent event,
    required CapturedEvidence evidence,
  }) async {
    final normalizedUserId = EvidencePolicy.validateUserId(userId);
    final normalizedOfficeId = EvidencePolicy.validateOfficeId(officeId);

    EvidencePolicy.validateCapturedEvidence(evidence);

    final attendanceId = workDay.documentIdFor(normalizedUserId);

    final path = EvidencePolicy.pathFor(
      userId: normalizedUserId,
      workDay: workDay,
      event: event,
    );

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'ownerUid': normalizedUserId,
        'attendanceId': attendanceId,
        'eventName': event.value,
        'officeId': normalizedOfficeId,
        'schemaVersion': '1',
      },
    );

    try {
      await _storage.ref(path).putData(evidence.bytes, metadata);

      return path;
    } on FirebaseException catch (error) {
      throw _failureFromFirebase(error);
    } catch (_) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.unavailable,
        message: 'No se pudo almacenar la evidencia fotográfica.',
      );
    }
  }

  @override
  Future<void> deleteIfExists({required String path}) async {
    final normalizedPath = _validateEvidencePath(path);

    try {
      await _storage.ref(normalizedPath).delete();
    } on FirebaseException catch (error) {
      if (error.code == 'object-not-found') {
        return;
      }

      throw _failureFromFirebase(error);
    } catch (_) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.unavailable,
        message: 'No se pudo limpiar la evidencia pendiente.',
      );
    }
  }

  String _validateEvidencePath(String path) {
    final normalized = path.trim();
    final segments = normalized.split('/');

    final validFileName =
        segments.length == 4 &&
        (segments[3] == 'check-in.jpg' || segments[3] == 'check-out.jpg');

    final valid =
        normalized == path &&
        segments.length == 4 &&
        segments[0] == 'attendanceEvidence' &&
        segments[1].isNotEmpty &&
        segments[2].isNotEmpty &&
        validFileName;

    if (!valid) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.invalidData,
        message: 'La ruta de la evidencia no es válida.',
      );
    }

    return normalized;
  }

  EvidenceFailure _failureFromFirebase(FirebaseException error) {
    return switch (error.code) {
      'unauthenticated' => const EvidenceFailure(
        code: EvidenceFailureCode.unauthenticated,
        message: 'Debes iniciar sesión para almacenar la fotografía.',
      ),
      'unauthorized' => const EvidenceFailure(
        code: EvidenceFailureCode.permissionDenied,
        message: 'Las reglas de Storage rechazaron la evidencia fotográfica.',
      ),
      'quota-exceeded' ||
      'bucket-not-found' ||
      'project-not-found' => const EvidenceFailure(
        code: EvidenceFailureCode.unavailable,
        message:
            'Firebase Storage no está disponible con la configuración actual. '
            'Utiliza el emulador para la demostración.',
      ),
      'invalid-argument' || 'invalid-checksum' => const EvidenceFailure(
        code: EvidenceFailureCode.invalidData,
        message: 'Firebase Storage rechazó los datos de la fotografía.',
      ),
      'retry-limit-exceeded' ||
      'canceled' ||
      'unknown' => const EvidenceFailure(
        code: EvidenceFailureCode.unavailable,
        message:
            'No se pudo completar la carga de la fotografía. '
            'Comprueba la conexión e inténtalo nuevamente.',
      ),
      _ => const EvidenceFailure(
        code: EvidenceFailureCode.unavailable,
        message: 'No se pudo almacenar la evidencia fotográfica.',
      ),
    };
  }
}
