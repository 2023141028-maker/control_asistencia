final class FaceProfile {
  const FaceProfile({
    required this.userId,
    required this.embedding,
    required this.modelVersion,
  });

  final String userId;
  final List<double> embedding;
  final String modelVersion;
}

final class FaceVerificationResult {
  const FaceVerificationResult({required this.similarity});

  final double similarity;
  bool get verified => similarity >= FaceVerificationPolicy.minimumSimilarity;
}

abstract final class FaceVerificationPolicy {
  static const embeddingLength = 192;
  static const minimumSimilarity = 0.60;
  static const modelVersion = 'mobilefacenet_192_v1';
}

class FaceVerificationFailure implements Exception {
  const FaceVerificationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
