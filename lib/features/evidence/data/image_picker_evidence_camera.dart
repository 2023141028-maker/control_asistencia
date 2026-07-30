import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/attendance_evidence.dart';
import '../domain/evidence_services.dart';

final class ImagePickerEvidenceCamera implements EvidenceCamera {
  ImagePickerEvidenceCamera({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<CapturedEvidence?> capture() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
        requestFullMetadata: false,
      );

      if (file == null) {
        return null;
      }

      return _evidenceFromFile(file);
    } on EvidenceFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw _failureFromPlatform(error);
    } catch (_) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.captureFailed,
        message: 'No se pudo procesar la fotografía capturada.',
      );
    }
  }

  @override
  Future<CapturedEvidence?> recoverLostCapture() async {
    try {
      final response = await _imagePicker.retrieveLostData();

      if (response.isEmpty) {
        return null;
      }

      final files = response.files;

      if (files != null && files.isNotEmpty) {
        return _evidenceFromFile(files.first);
      }

      final exception = response.exception;

      if (exception != null) {
        throw _failureFromPlatform(exception);
      }

      return null;
    } on EvidenceFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw _failureFromPlatform(error);
    } catch (_) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.captureFailed,
        message: 'No se pudo recuperar la fotografía pendiente.',
      );
    }
  }

  Future<CapturedEvidence> _evidenceFromFile(XFile file) async {
    final bytes = await file.readAsBytes();

    final evidence = CapturedEvidence(
      bytes: bytes,
      capturedAt: DateTime.now().toUtc(),
    );

    EvidencePolicy.validateCapturedEvidence(evidence);

    return evidence;
  }

  EvidenceFailure _failureFromPlatform(PlatformException error) {
    final code = error.code.toLowerCase();

    if (code.contains('denied') ||
        code.contains('restricted') ||
        code.contains('permission')) {
      return const EvidenceFailure(
        code: EvidenceFailureCode.cameraPermissionDenied,
        message:
            'No se puede tomar la fotografía porque el permiso de cámara '
            'fue rechazado.',
      );
    }

    return const EvidenceFailure(
      code: EvidenceFailureCode.captureFailed,
      message: 'La cámara no pudo capturar la fotografía.',
    );
  }
}
