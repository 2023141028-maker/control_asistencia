import '../../evidence/domain/attendance_evidence.dart';
import '../../evidence/domain/evidence_services.dart';
import '../../face_verification/data/firestore_face_profile_repository.dart';
import '../../face_verification/data/mobile_face_verification_service.dart';
import '../../face_verification/domain/face_profile.dart';
import '../../location/domain/device_location.dart';
import '../../location/domain/geofence_validator.dart';
import '../../location/domain/location_service.dart';
import '../../offices/domain/office.dart';
import '../../privacy/domain/privacy_policy.dart';
import '../domain/attendance_day.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_repository.dart';

typedef AttendanceClock = DateTime Function();

final class AttendanceRegistrationResult {
  const AttendanceRegistrationResult({
    required this.event,
    required this.record,
    required this.workDay,
    required this.evidencePath,
    required this.location,
  });

  final EvidenceEvent event;
  final AttendanceRecord record;
  final AttendanceDay workDay;
  final String evidencePath;
  final DeviceLocation location;

  String get message => switch (event) {
    EvidenceEvent.checkIn => 'Entrada registrada correctamente.',
    EvidenceEvent.checkOut => 'Salida registrada correctamente.',
  };
}

final class AttendanceRegistrationService {
  factory AttendanceRegistrationService({
    required AttendanceRepository attendanceRepository,
    required EvidenceRepository evidenceRepository,
    required EvidenceCamera evidenceCamera,
    required LocationService locationService,
    FirestoreFaceProfileRepository? faceProfileRepository,
    MobileFaceVerificationService? faceVerificationService,
    GeofenceValidator? geofenceValidator,
    AttendanceClock? clock,
  }) {
    return AttendanceRegistrationService._(
      attendanceRepository,
      evidenceRepository,
      evidenceCamera,
      locationService,
      faceProfileRepository,
      faceVerificationService,
      geofenceValidator ?? const GeofenceValidator(),
      clock ?? DateTime.now,
    );
  }

  AttendanceRegistrationService._(
    this._attendanceRepository,
    this._evidenceRepository,
    this._evidenceCamera,
    this._locationService,
    this._faceProfileRepository,
    this._faceVerificationService,
    this._geofenceValidator,
    this._clock,
  );

  final AttendanceRepository _attendanceRepository;
  final EvidenceRepository _evidenceRepository;
  final EvidenceCamera _evidenceCamera;
  final LocationService _locationService;
  final FirestoreFaceProfileRepository? _faceProfileRepository;
  final MobileFaceVerificationService? _faceVerificationService;
  final GeofenceValidator _geofenceValidator;
  final AttendanceClock _clock;

  Future<AttendanceRegistrationResult?> registerNextEvent({
    required String userId,
    required Office office,
    required bool privacyConsentAccepted,
  }) async {
    if (!privacyConsentAccepted) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.privacyConsentRequired,
        message:
            'Debes aceptar el aviso de privacidad antes de registrar la '
            'asistencia.',
      );
    }

    final normalizedUserId = EvidencePolicy.validateUserId(userId);
    final normalizedOfficeId = EvidencePolicy.validateOfficeId(office.id);

    if (normalizedOfficeId != office.id) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.invalidData,
        message: 'La sede asignada no es válida.',
      );
    }

    final workDay = AttendanceDay.fromInstant(_clock());

    final currentRecord = await _attendanceRepository.getForDay(
      userId: normalizedUserId,
      workDay: workDay,
    );

    final event = _nextEventFor(currentRecord);

    final recoveredEvidence = await _evidenceCamera.recoverLostCapture();

    final evidence = recoveredEvidence ?? await _evidenceCamera.capture();

    if (evidence == null) {
      return null;
    }

    EvidencePolicy.validateCapturedEvidence(evidence);

    double? faceSimilarity;
    final profileRepository = _faceProfileRepository;
    final verificationService = _faceVerificationService;
    if (profileRepository != null && verificationService != null) {
      if (!evidence.livenessVerified || evidence.livenessChallenge == null) {
        throw const FaceVerificationFailure(
          'No se pudo comprobar la prueba de vida.',
        );
      }
      final profile = await profileRepository.get(normalizedUserId);
      if (profile == null ||
          profile.modelVersion != FaceVerificationPolicy.modelVersion) {
        throw const FaceVerificationFailure(
          'Tu rostro aún no fue registrado. Solicita la matrícula facial al administrador.',
        );
      }
      final candidate = await verificationService.createEmbedding(evidence.bytes);
      faceSimilarity = verificationService.compare(profile.embedding, candidate);
      if (faceSimilarity < FaceVerificationPolicy.minimumSimilarity) {
        throw const FaceVerificationFailure(
          'El rostro no coincide con el trabajador autenticado.',
        );
      }
    }

    final location = await _locationService.getCurrentLocation();

    final locationValidation = _geofenceValidator.validate(
      office: office,
      location: location,
    );

    if (!locationValidation.isAllowed) {
      throw AttendanceFailure(
        code: AttendanceFailureCode.locationNotAllowed,
        message: locationValidation.message,
      );
    }

    final evidencePath = await _evidenceRepository.upload(
      userId: normalizedUserId,
      officeId: normalizedOfficeId,
      workDay: workDay,
      event: event,
      evidence: evidence,
    );

    final command = AttendanceRegistrationCommand(
      userId: normalizedUserId,
      office: office,
      workDay: workDay,
      location: location,
      evidencePath: evidencePath,
      faceSimilarity: faceSimilarity,
      livenessVerified: evidence.livenessVerified,
      livenessChallenge: evidence.livenessChallenge,
      privacyConsentAccepted: privacyConsentAccepted,
      privacyConsentVersion: PrivacyPolicy.noticeVersion,
      evidenceRetentionUntil: PrivacyPolicy.evidenceRetentionUntil(
        location.capturedAt,
      ),
    );

    try {
      final record = switch (event) {
        EvidenceEvent.checkIn => await _attendanceRepository.registerCheckIn(
          command: command,
        ),
        EvidenceEvent.checkOut => await _attendanceRepository.registerCheckOut(
          command: command,
        ),
      };

      return AttendanceRegistrationResult(
        event: event,
        record: record,
        workDay: workDay,
        evidencePath: evidencePath,
        location: location,
      );
    } catch (error, stackTrace) {
      try {
        await _evidenceRepository.deleteIfExists(path: evidencePath);
      } catch (_) {
        throw const EvidenceFailure(
          code: EvidenceFailureCode.unavailable,
          message:
              'La asistencia no fue registrada y no se pudo limpiar la '
              'fotografía pendiente. Comunícate con el administrador.',
        );
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  EvidenceEvent _nextEventFor(AttendanceRecord? record) {
    if (record == null) {
      return EvidenceEvent.checkIn;
    }

    if (record.status == AttendanceStatus.checkedIn &&
        record.checkOut == null) {
      return EvidenceEvent.checkOut;
    }

    if (record.hasCompletedDay) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.alreadyCheckedOut,
        message: 'La jornada de hoy ya fue completada.',
      );
    }

    throw const AttendanceFailure(
      code: AttendanceFailureCode.invalidData,
      message: 'El estado actual de la asistencia no es válido.',
    );
  }
}
