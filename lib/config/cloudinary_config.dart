final class CloudinaryConfig {
  const CloudinaryConfig({
    required this.cloudName,
    required this.unsignedUploadPreset,
  });

  factory CloudinaryConfig.fromEnvironment() {
    const cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
    const uploadPreset = String.fromEnvironment(
      'CLOUDINARY_UNSIGNED_UPLOAD_PRESET',
    );

    return const CloudinaryConfig(
      cloudName: cloudName,
      unsignedUploadPreset: uploadPreset,
    );
  }

  final String cloudName;
  final String unsignedUploadPreset;

  bool get isConfigured =>
      _isSafeIdentifier(cloudName) &&
      _isSafeIdentifier(unsignedUploadPreset);

  Uri get imageUploadUri => Uri.https(
    'api.cloudinary.com',
    '/v1_1/$cloudName/image/upload',
  );

  static bool _isSafeIdentifier(String value) {
    return value.isNotEmpty &&
        value.length <= 100 &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
  }
}
