import 'user_profile.dart';

abstract interface class UserRepository {
  Stream<UserProfile?> watchProfile({required String uid});
}

class UserProfileFailure implements Exception {
  const UserProfileFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
