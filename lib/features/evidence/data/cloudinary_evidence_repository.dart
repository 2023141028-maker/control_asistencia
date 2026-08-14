import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../config/cloudinary_config.dart';
import '../../attendance/domain/attendance_day.dart';
import '../domain/attendance_evidence.dart';
import '../domain/evidence_services.dart';

final class CloudinaryEvidenceRepository implements EvidenceRepository {
  CloudinaryEvidenceRepository({
    CloudinaryConfig? config,
    http.Client? client,
  }) : _config = config ?? CloudinaryConfig.fromEnvironment(),
       _client = client ?? http.Client();

  final CloudinaryConfig _config;
  final http.Client _client;

  @override
  Future<String> upload({
    required String userId,
    required String officeId,
    required AttendanceDay workDay,
    required EvidenceEvent event,
    required CapturedEvidence evidence,
  }) async {
    EvidencePolicy.validateUserId(userId);
    EvidencePolicy.validateOfficeId(officeId);
    EvidencePolicy.validateCapturedEvidence(evidence);

    if (!_config.isConfigured) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.unavailable,
        message:
            'Cloudinary no está configurado. Define CLOUDINARY_CLOUD_NAME y '
            'CLOUDINARY_UNSIGNED_UPLOAD_PRESET al ejecutar la aplicación.',
      );
    }

    final request = http.MultipartRequest('POST', _config.imageUploadUri)
      ..fields['upload_preset'] = _config.unsignedUploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          evidence.bytes,
          filename: event.fileName,
        ),
      );

    try {
      final streamed = await _client.send(request).timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw EvidenceFailure(
          code: EvidenceFailureCode.unavailable,
          message: _safeUploadError(body),
        );
      }

      if (body is! Map<String, dynamic>) {
        throw const EvidenceFailure(
          code: EvidenceFailureCode.invalidData,
          message: 'Cloudinary devolvió una respuesta no válida.',
        );
      }

      final secureUrl = body['secure_url'];
      if (secureUrl is! String || !_isAllowedCloudinaryUrl(secureUrl)) {
        throw const EvidenceFailure(
          code: EvidenceFailureCode.invalidData,
          message: 'Cloudinary no devolvió una URL de evidencia válida.',
        );
      }

      return secureUrl;
    } on EvidenceFailure {
      rethrow;
    } catch (_) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.unavailable,
        message:
            'No se pudo almacenar la evidencia. Comprueba la conexión e '
            'inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deleteIfExists({required String path}) async {
    // Un cliente móvil nunca debe contener el API secret de Cloudinary.
    // La eliminación autenticada se realizará posteriormente desde un backend
    // confiable aplicando la política de conservación de evidencias.
    if (!_isAllowedCloudinaryUrl(path)) {
      throw const EvidenceFailure(
        code: EvidenceFailureCode.invalidData,
        message: 'La referencia de la evidencia no es válida.',
      );
    }
  }

  bool _isAllowedCloudinaryUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'res.cloudinary.com' &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == _config.cloudName &&
        uri.path.contains('/image/upload/');
  }

  String _safeUploadError(Object? body) {
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        final raw = (error['message'] as String)
            .replaceAll(RegExp(r'[\r\n]+'), ' ')
            .trim();
        final safe = raw.length <= 160 ? raw : raw.substring(0, 160);
        return 'Cloudinary rechazó la evidencia: $safe';
      }
    }
    return 'Cloudinary rechazó la evidencia fotográfica.';
  }
}
