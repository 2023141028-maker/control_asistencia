import 'package:control_asistencia/features/evidence/domain/liveness_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = LivenessValidator();
  const neutral = FacePose(yaw: 1, roll: -1);

  test('acepta una toma frontal dentro de los límites', () {
    expect(validator.isNeutral(neutral), isTrue);
    expect(
      validator.isNeutral(const FacePose(yaw: 19, roll: 0)),
      isFalse,
    );
  });

  test('valida un giro suficiente respecto de la toma frontal', () {
    expect(
      validator.validates(
        challenge: LivenessChallenge.turnHead,
        neutral: neutral,
        response: const FacePose(yaw: 21, roll: 0),
      ),
      isTrue,
    );
    expect(
      validator.validates(
        challenge: LivenessChallenge.turnHead,
        neutral: neutral,
        response: const FacePose(yaw: 10, roll: 0),
      ),
      isFalse,
    );
  });

  test('valida una inclinación suficiente respecto de la toma frontal', () {
    expect(
      validator.validates(
        challenge: LivenessChallenge.tiltHead,
        neutral: neutral,
        response: const FacePose(yaw: 0, roll: 16),
      ),
      isTrue,
    );
    expect(
      validator.validates(
        challenge: LivenessChallenge.tiltHead,
        neutral: neutral,
        response: const FacePose(yaw: 0, roll: 5),
      ),
      isFalse,
    );
  });
}
