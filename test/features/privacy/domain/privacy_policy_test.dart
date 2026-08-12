import 'package:control_asistencia/features/privacy/domain/privacy_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calcula una conservación exacta de 90 días en UTC', () {
    final recordedAt = DateTime.parse('2026-08-10T14:30:00-05:00');

    final retentionUntil = PrivacyPolicy.evidenceRetentionUntil(recordedAt);

    expect(retentionUntil, DateTime.utc(2026, 11, 8, 19, 30));
    expect(
      PrivacyPolicy.isValidRetentionWindow(
        recordedAt: recordedAt,
        retentionUntil: retentionUntil,
      ),
      isTrue,
    );
  });

  test('rechaza una fecha de conservación modificada', () {
    final recordedAt = DateTime.utc(2026, 8, 10);

    expect(
      PrivacyPolicy.isValidRetentionWindow(
        recordedAt: recordedAt,
        retentionUntil: recordedAt.add(const Duration(days: 91)),
      ),
      isFalse,
    );
  });
}
