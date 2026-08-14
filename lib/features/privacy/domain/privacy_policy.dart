abstract final class PrivacyPolicy {
  static const noticeVersion = '1.1';
  static const retentionPolicyVersion = '1.0';
  static const evidencePurpose = 'attendance-verification';
  static const evidenceRetentionDays = 90;

  static DateTime evidenceRetentionUntil(DateTime recordedAt) {
    return recordedAt.toUtc().add(
      const Duration(days: evidenceRetentionDays),
    );
  }

  static bool isValidRetentionWindow({
    required DateTime recordedAt,
    required DateTime retentionUntil,
  }) {
    return retentionUntil.toUtc() == evidenceRetentionUntil(recordedAt);
  }
}
