enum LivenessChallenge { turnHead, tiltHead }

extension LivenessChallengeDetails on LivenessChallenge {
  String get value => switch (this) {
    LivenessChallenge.turnHead => 'turn-head',
    LivenessChallenge.tiltHead => 'tilt-head',
  };

  String get instruction => switch (this) {
    LivenessChallenge.turnHead =>
      'Gira claramente la cabeza hacia un lado',
    LivenessChallenge.tiltHead =>
      'Inclina claramente la cabeza hacia un hombro',
  };
}

final class FacePose {
  const FacePose({required this.yaw, required this.roll});

  final double yaw;
  final double roll;
}

final class LivenessValidator {
  const LivenessValidator();

  static const minimumTurnDelta = 18.0;
  static const minimumTiltDelta = 14.0;

  bool isNeutral(FacePose pose) {
    return pose.yaw.abs() <= 18 && pose.roll.abs() <= 15;
  }

  bool validates({
    required LivenessChallenge challenge,
    required FacePose neutral,
    required FacePose response,
  }) {
    return switch (challenge) {
      LivenessChallenge.turnHead =>
        (response.yaw - neutral.yaw).abs() >= minimumTurnDelta,
      LivenessChallenge.tiltHead =>
        (response.roll - neutral.roll).abs() >= minimumTiltDelta,
    };
  }
}
