import 'package:cloud_firestore/cloud_firestore.dart';

import '../../privacy/domain/privacy_policy.dart';
import '../domain/face_profile.dart';

final class FirestoreFaceProfileRepository {
  FirestoreFaceProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<FaceProfile?> get(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('faceProfiles')
          .doc(userId)
          .get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      if (data['active'] != true ||
          data['consentAccepted'] != true ||
          data['consentVersion'] != '1.0') {
        throw const FaceVerificationFailure(
          'La plantilla facial no tiene un consentimiento activo.',
        );
      }
      final values = data['embedding'];
      if (values is! List ||
          values.length != FaceVerificationPolicy.embeddingLength) {
        throw const FaceVerificationFailure(
          'La plantilla facial almacenada no es válida.',
        );
      }
      return FaceProfile(
        userId: userId,
        embedding: values
            .map((value) => (value as num).toDouble())
            .toList(growable: false),
        modelVersion: data['modelVersion'] as String? ?? '',
      );
    } on FaceVerificationFailure {
      rethrow;
    } on FirebaseException catch (_) {
      throw const FaceVerificationFailure(
        'No se pudo consultar la plantilla facial.',
      );
    }
  }

  Future<void> save({
    required String userId,
    required List<double> embedding,
    required String enrolledBy,
    required bool consentConfirmed,
  }) async {
    if (!consentConfirmed) {
      throw const FaceVerificationFailure(
        'La matrícula facial requiere el consentimiento del trabajador.',
      );
    }
    if (embedding.length != FaceVerificationPolicy.embeddingLength) {
      throw const FaceVerificationFailure(
        'La plantilla facial generada no es válida.',
      );
    }
    try {
      await _firestore.collection('faceProfiles').doc(userId).set({
        'userId': userId,
        'embedding': embedding,
        'modelVersion': FaceVerificationPolicy.modelVersion,
        'consentAccepted': true,
        'consentVersion': '1.0',
        'privacyNoticeVersion': PrivacyPolicy.noticeVersion,
        'retentionPolicyVersion': PrivacyPolicy.retentionPolicyVersion,
        'consentMethod': 'in-person-explicit',
        'consentRecordedAt': FieldValue.serverTimestamp(),
        'consentRecordedBy': enrolledBy,
        'enrolledBy': enrolledBy,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (_) {
      throw const FaceVerificationFailure(
        'No se pudo guardar la plantilla facial.',
      );
    }
  }
}
