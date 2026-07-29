import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/user_profile.dart';
import '../domain/user_repository.dart';

final class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<UserProfile?> watchProfile({required String uid}) async* {
    final reference = _firestore.collection('users').doc(uid);

    try {
      await for (final snapshot in reference.snapshots()) {
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          yield null;
          continue;
        }

        yield _profileFromData(documentId: snapshot.id, data: data);
      }
    } on UserProfileFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw UserProfileFailure(_messageForCode(error.code));
    } catch (_) {
      throw const UserProfileFailure(
        'No se pudo interpretar el perfil del usuario.',
      );
    }
  }

  UserProfile _profileFromData({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final profile = UserProfile(
      uid: _requiredString(data, 'uid'),
      email: _requiredString(data, 'email'),
      fullName: _requiredString(data, 'fullName'),
      employeeCode: _requiredString(data, 'employeeCode'),
      role: _roleFromValue(data['role']),
      status: _statusFromValue(data['status']),
      officeId: _nullableString(data, 'officeId'),
      schemaVersion: _requiredInt(data, 'schemaVersion'),
      createdAt: _requiredTimestamp(data, 'createdAt').toDate(),
      updatedAt: _requiredTimestamp(data, 'updatedAt').toDate(),
    );

    if (profile.uid != documentId || profile.schemaVersion != 1) {
      throw const UserProfileFailure(
        'El perfil tiene una estructura incompatible.',
      );
    }

    return profile;
  }

  String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw UserProfileFailure('El campo $field no es válido.');
  }

  String? _nullableString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw UserProfileFailure('El campo $field no es válido.');
  }

  int _requiredInt(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is int) {
      return value;
    }

    throw UserProfileFailure('El campo $field no es válido.');
  }

  Timestamp _requiredTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is Timestamp) {
      return value;
    }

    throw UserProfileFailure('El campo $field no es válido.');
  }

  UserRole _roleFromValue(Object? value) {
    return switch (value) {
      'admin' => UserRole.admin,
      'employee' => UserRole.employee,
      _ => throw const UserProfileFailure('El rol no es válido.'),
    };
  }

  UserStatus _statusFromValue(Object? value) {
    return switch (value) {
      'active' => UserStatus.active,
      'inactive' => UserStatus.inactive,
      'pending' => UserStatus.pending,
      _ => throw const UserProfileFailure('El estado no es válido.'),
    };
  }

  String _messageForCode(String code) {
    return switch (code) {
      'permission-denied' => 'No tienes permiso para consultar este perfil.',
      'unavailable' => 'No se pudo conectar con Firestore.',
      _ => 'No se pudo cargar el perfil del usuario.',
    };
  }
}
