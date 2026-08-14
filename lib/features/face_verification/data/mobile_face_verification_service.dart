import 'dart:typed_data';

import 'package:face_detection_tflite/face_detection_tflite.dart' as fdt;

import '../domain/face_profile.dart';

final class MobileFaceVerificationService {
  Future<List<double>> createEmbedding(Uint8List imageBytes) async {
    final detector = await fdt.FaceDetector.create();
    try {
      final faces = await detector.detectFacesFromBytes(
        imageBytes,
        mode: fdt.FaceDetectionMode.full,
      );
      if (faces.length != 1) {
        throw const FaceVerificationFailure(
          'Debe aparecer un solo rostro para validar la identidad.',
        );
      }
      final raw = await detector.getFaceEmbedding(faces.single, imageBytes);
      final embedding = raw.map((value) => value.toDouble()).toList(growable: false);
      if (embedding.length != FaceVerificationPolicy.embeddingLength) {
        throw const FaceVerificationFailure('No se pudo generar la plantilla facial.');
      }
      return embedding;
    } on FaceVerificationFailure {
      rethrow;
    } catch (_) {
      throw const FaceVerificationFailure('No se pudo procesar la identidad facial.');
    } finally {
      await detector.dispose();
    }
  }

  double compare(List<double> reference, List<double> candidate) {
    return fdt.FaceDetector.compareFaces(
      Float32List.fromList(reference),
      Float32List.fromList(candidate),
    );
  }
}
