import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/office.dart';
import '../domain/office_repository.dart';

final class FirestoreOfficeRepository implements OfficeRepository {
  FirestoreOfficeRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<Office?> watchOffice({required String officeId}) async* {
    final reference = _firestore.collection('offices').doc(officeId);

    try {
      await for (final snapshot in reference.snapshots()) {
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          yield null;
          continue;
        }

        yield _officeFromData(documentId: snapshot.id, data: data);
      }
    } on OfficeFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw OfficeFailure(_messageForCode(error.code));
    } catch (_) {
      throw const OfficeFailure(
        'No se pudo interpretar la configuración de la sede.',
      );
    }
  }

  Office _officeFromData({
    required String documentId,
    required Map<String, dynamic> data,
  }) {
    final location = _requiredGeoPoint(data, 'location');

    final office = Office(
      id: documentId,
      name: _requiredString(data, 'name'),
      address: _requiredString(data, 'address'),
      latitude: location.latitude,
      longitude: location.longitude,
      radiusMeters: _requiredNumber(data, 'radiusMeters'),
      maxAccuracyMeters: _requiredNumber(data, 'maxAccuracyMeters'),
      timezone: _requiredString(data, 'timezone'),
      active: _requiredBool(data, 'active'),
      schemaVersion: _requiredInt(data, 'schemaVersion'),
      createdAt: _requiredTimestamp(data, 'createdAt').toDate(),
      updatedAt: _requiredTimestamp(data, 'updatedAt').toDate(),
    );

    if (office.schemaVersion != 1 ||
        office.radiusMeters <= 0 ||
        office.maxAccuracyMeters <= 0 ||
        office.timezone != 'America/Lima') {
      throw const OfficeFailure(
        'La sede tiene una configuración incompatible.',
      );
    }

    return office;
  }

  String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw OfficeFailure('El campo $field no es válido.');
  }

  double _requiredNumber(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is num) {
      return value.toDouble();
    }

    throw OfficeFailure('El campo $field no es válido.');
  }

  int _requiredInt(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is int) {
      return value;
    }

    throw OfficeFailure('El campo $field no es válido.');
  }

  bool _requiredBool(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is bool) {
      return value;
    }

    throw OfficeFailure('El campo $field no es válido.');
  }

  GeoPoint _requiredGeoPoint(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is GeoPoint) {
      return value;
    }

    throw OfficeFailure('El campo $field no es un GeoPoint válido.');
  }

  Timestamp _requiredTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is Timestamp) {
      return value;
    }

    throw OfficeFailure('El campo $field no es válido.');
  }

  String _messageForCode(String code) {
    return switch (code) {
      'permission-denied' => 'No tienes permiso para consultar esta sede.',
      'unavailable' => 'No se pudo conectar con Firestore para cargar la sede.',
      _ => 'No se pudo cargar la sede.',
    };
  }
}
