import 'package:cloud_firestore/cloud_firestore.dart';

import '../../location/domain/geofence_validator.dart';
import '../domain/attendance_day.dart';
import '../domain/attendance_record.dart';
import '../domain/attendance_repository.dart';

final class FirestoreAttendanceRepository implements AttendanceRepository {
  FirestoreAttendanceRepository({
    FirebaseFirestore? firestore,
    GeofenceValidator? geofenceValidator,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _geofenceValidator = geofenceValidator ?? const GeofenceValidator();

  final FirebaseFirestore _firestore;
  final GeofenceValidator _geofenceValidator;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('attendances');
  }

  @override
  Future<AttendanceRecord?> getForDay({
    required String userId,
    required AttendanceDay workDay,
  }) async {
    final normalizedUserId = _validateUserId(userId);
    final documentId = workDay.documentIdFor(normalizedUserId);
    final reference = _collection.doc(documentId);

    try {
      final snapshot = await reference.get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return _recordFromSnapshot(snapshot);
    } on AttendanceFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _failureFromFirebase(error);
    } catch (_) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'No se pudo interpretar la asistencia.',
      );
    }
  }

  @override
  Stream<List<AttendanceRecord>> watchHistory({
    required String userId,
    int limit = 30,
  }) async* {
    final normalizedUserId = _validateUserId(userId);

    if (limit < 1 || limit > 50) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'El límite del historial debe estar entre 1 y 50.',
      );
    }

    final query = _collection
        .where('userId', isEqualTo: normalizedUserId)
        .orderBy('workDate', descending: true)
        .limit(limit);

    try {
      await for (final snapshot in query.snapshots()) {
        final records = snapshot.docs
            .map(_recordFromSnapshot)
            .toList(growable: false);

        yield records;
      }
    } on AttendanceFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _failureFromFirebase(error);
    } catch (_) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'No se pudo interpretar el historial de asistencias.',
      );
    }
  }

  @override
  Future<AttendanceRecord> registerCheckIn({
    required AttendanceRegistrationCommand command,
  }) async {
    final prepared = _prepareCommand(command: command, eventName: 'check-in');

    final reference = _collection.doc(prepared.attendanceId);

    try {
      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(reference);

        if (snapshot.exists) {
          throw const AttendanceFailure(
            code: AttendanceFailureCode.duplicateCheckIn,
            message: 'La entrada de este día ya fue registrada.',
          );
        }

        transaction.set(reference, {
          'userId': prepared.userId,
          'officeId': command.office.id,
          'workDate': command.workDay.value,
          'mode': AttendanceMode.onsite.value,
          'status': AttendanceStatus.checkedIn.value,
          'checkIn': _markData(
            command: command,
            distanceMeters: prepared.distanceMeters,
          ),
          'checkOut': null,
          'schemaVersion': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return _readFromServer(reference);
    } on AttendanceFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _failureFromFirebase(error);
    } catch (_) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.unavailable,
        message: 'No se pudo registrar la entrada.',
      );
    }
  }

  @override
  Future<AttendanceRecord> registerCheckOut({
    required AttendanceRegistrationCommand command,
  }) async {
    final prepared = _prepareCommand(command: command, eventName: 'check-out');

    final reference = _collection.doc(prepared.attendanceId);

    try {
      await _firestore.runTransaction<void>((transaction) async {
        final snapshot = await transaction.get(reference);
        final data = snapshot.data();

        if (!snapshot.exists || data == null) {
          throw const AttendanceFailure(
            code: AttendanceFailureCode.missingCheckIn,
            message: 'Primero debes registrar la entrada.',
          );
        }

        if (data['userId'] != prepared.userId ||
            data['officeId'] != command.office.id ||
            data['workDate'] != command.workDay.value) {
          throw const AttendanceFailure(
            code: AttendanceFailureCode.invalidData,
            message: 'La asistencia existente no coincide con la solicitud.',
          );
        }

        if (data['status'] == AttendanceStatus.completed.value ||
            data['checkOut'] != null) {
          throw const AttendanceFailure(
            code: AttendanceFailureCode.alreadyCheckedOut,
            message: 'La salida de este día ya fue registrada.',
          );
        }

        if (data['status'] != AttendanceStatus.checkedIn.value) {
          throw const AttendanceFailure(
            code: AttendanceFailureCode.invalidData,
            message: 'El estado de la asistencia no es válido.',
          );
        }

        transaction.update(reference, {
          'status': AttendanceStatus.completed.value,
          'checkOut': _markData(
            command: command,
            distanceMeters: prepared.distanceMeters,
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      return _readFromServer(reference);
    } on AttendanceFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw _failureFromFirebase(error);
    } catch (_) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.unavailable,
        message: 'No se pudo registrar la salida.',
      );
    }
  }

  _PreparedAttendanceCommand _prepareCommand({
    required AttendanceRegistrationCommand command,
    required String eventName,
  }) {
    final userId = _validateUserId(command.userId);
    final officeId = command.office.id.trim();

    if (officeId.isEmpty ||
        officeId != command.office.id ||
        officeId.contains('/')) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'La sede de la asistencia no es válida.',
      );
    }

    final attendanceId = command.workDay.documentIdFor(userId);

    final expectedEvidencePath =
        'attendanceEvidence/'
        '$userId/'
        '$attendanceId/'
        '$eventName.jpg';

    if (command.evidencePath.trim() != expectedEvidencePath) {
      throw AttendanceFailure(
        code: AttendanceFailureCode.evidenceRequired,
        message: 'La evidencia debe almacenarse en $expectedEvidencePath.',
      );
    }

    if (command.location.isMocked) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.locationNotAllowed,
        message: 'No se puede registrar asistencia con una ubicación simulada.',
      );
    }

    final validation = _geofenceValidator.validate(
      office: command.office,
      location: command.location,
    );

    if (!validation.isAllowed) {
      throw AttendanceFailure(
        code: AttendanceFailureCode.locationNotAllowed,
        message: validation.message,
      );
    }

    return _PreparedAttendanceCommand(
      userId: userId,
      attendanceId: attendanceId,
      distanceMeters: validation.distanceMeters,
    );
  }

  Map<String, dynamic> _markData({
    required AttendanceRegistrationCommand command,
    required double distanceMeters,
  }) {
    return {
      'capturedAt': Timestamp.fromDate(command.location.capturedAt.toUtc()),
      'recordedAt': FieldValue.serverTimestamp(),
      'location': GeoPoint(
        command.location.latitude,
        command.location.longitude,
      ),
      'accuracyMeters': command.location.accuracyMeters,
      'distanceMeters': distanceMeters,
      'isMocked': command.location.isMocked,
      'evidencePath': command.evidencePath,
    };
  }

  Future<AttendanceRecord> _readFromServer(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    final snapshot = await reference.get(
      const GetOptions(source: Source.server),
    );

    if (!snapshot.exists || snapshot.data() == null) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'Firestore no devolvió la asistencia registrada.',
      );
    }

    return _recordFromSnapshot(snapshot);
  }

  AttendanceRecord _recordFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'El documento de asistencia no existe.',
      );
    }

    final workDay = AttendanceDay.parse(_requiredString(data, 'workDate'));

    final checkIn = _markFromMap(_requiredMap(data, 'checkIn'));

    final checkOutData = data['checkOut'];

    final checkOut = checkOutData == null
        ? null
        : _markFromMap(_mapFromValue(checkOutData, 'checkOut'));

    final record = AttendanceRecord(
      id: snapshot.id,
      userId: _requiredString(data, 'userId'),
      officeId: _requiredString(data, 'officeId'),
      workDay: workDay,
      mode: _modeFromValue(data['mode']),
      status: _statusFromValue(data['status']),
      checkIn: checkIn,
      checkOut: checkOut,
      schemaVersion: _requiredInt(data, 'schemaVersion'),
      createdAt: _requiredTimestamp(data, 'createdAt').toDate(),
      updatedAt: _requiredTimestamp(data, 'updatedAt').toDate(),
    );

    _validateRecord(record);

    return record;
  }

  AttendanceMark _markFromMap(Map<String, dynamic> data) {
    final location = _requiredGeoPoint(data, 'location');

    return AttendanceMark(
      capturedAt: _requiredTimestamp(data, 'capturedAt').toDate(),
      recordedAt: _requiredTimestamp(data, 'recordedAt').toDate(),
      latitude: location.latitude,
      longitude: location.longitude,
      accuracyMeters: _requiredNumber(data, 'accuracyMeters'),
      distanceMeters: _requiredNumber(data, 'distanceMeters'),
      isMocked: _requiredBool(data, 'isMocked'),
      evidencePath: _requiredString(data, 'evidencePath'),
    );
  }

  void _validateRecord(AttendanceRecord record) {
    final expectedDocumentId = record.workDay.documentIdFor(record.userId);

    final validStatus =
        (record.status == AttendanceStatus.checkedIn &&
            record.checkOut == null) ||
        (record.status == AttendanceStatus.completed &&
            record.checkOut != null);

    final validCheckInPath =
        record.checkIn.evidencePath ==
        'attendanceEvidence/'
            '${record.userId}/'
            '${record.id}/'
            'check-in.jpg';

    final validCheckOutPath =
        record.checkOut == null ||
        record.checkOut!.evidencePath ==
            'attendanceEvidence/'
                '${record.userId}/'
                '${record.id}/'
                'check-out.jpg';

    final validMarks =
        _isValidMark(record.checkIn) &&
        (record.checkOut == null || _isValidMark(record.checkOut!));

    final validChronology =
        record.createdAt.compareTo(record.updatedAt) <= 0 &&
        (record.checkOut == null ||
            record.checkOut!.recordedAt.compareTo(record.checkIn.recordedAt) >=
                0);

    if (record.schemaVersion != 1 ||
        record.id != expectedDocumentId ||
        !validStatus ||
        !validCheckInPath ||
        !validCheckOutPath ||
        !validMarks ||
        !validChronology) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'La asistencia tiene una estructura incompatible.',
      );
    }
  }

  bool _isValidMark(AttendanceMark mark) {
    return mark.accuracyMeters > 0 &&
        mark.distanceMeters >= 0 &&
        !mark.isMocked &&
        mark.evidencePath.isNotEmpty;
  }

  String _validateUserId(String userId) {
    final normalized = userId.trim();

    if (normalized.isEmpty ||
        normalized != userId ||
        normalized.contains('/') ||
        normalized.length > 128) {
      throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'El UID de la asistencia no es válido.',
      );
    }

    return normalized;
  }

  String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw AttendanceFailure(
      code: AttendanceFailureCode.invalidData,
      message: 'El campo $field no es válido.',
    );
  }

  double _requiredNumber(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is num) {
      return value.toDouble();
    }

    throw AttendanceFailure(
      code: AttendanceFailureCode.invalidData,
      message: 'El campo $field no es válido.',
    );
  }

  int _requiredInt(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is int) {
      return value;
    }

    throw AttendanceFailure(
      code: AttendanceFailureCode.invalidData,
      message: 'El campo $field no es válido.',
    );
  }

  bool _requiredBool(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is bool) {
      return value;
    }

    throw AttendanceFailure(
      code: AttendanceFailureCode.invalidData,
      message: 'El campo $field no es válido.',
    );
  }

  Timestamp _requiredTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is Timestamp) {
      return value;
    }

    throw AttendanceFailure(
      code: AttendanceFailureCode.invalidData,
      message: 'El campo $field no es válido.',
    );
  }

  GeoPoint _requiredGeoPoint(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is GeoPoint) {
      return value;
    }

    throw AttendanceFailure(
      code: AttendanceFailureCode.invalidData,
      message: 'El campo $field no es un GeoPoint válido.',
    );
  }

  Map<String, dynamic> _requiredMap(Map<String, dynamic> data, String field) {
    return _mapFromValue(data[field], field);
  }

  Map<String, dynamic> _mapFromValue(Object? value, String field) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        // El error se transforma en AttendanceFailure abajo.
      }
    }

    throw AttendanceFailure(
      code: AttendanceFailureCode.invalidData,
      message: 'El campo $field no es un mapa válido.',
    );
  }

  AttendanceMode _modeFromValue(Object? value) {
    return switch (value) {
      'onsite' => AttendanceMode.onsite,
      _ => throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'La modalidad de asistencia no es válida.',
      ),
    };
  }

  AttendanceStatus _statusFromValue(Object? value) {
    return switch (value) {
      'checked-in' => AttendanceStatus.checkedIn,
      'completed' => AttendanceStatus.completed,
      _ => throw const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'El estado de asistencia no es válido.',
      ),
    };
  }

  AttendanceFailure _failureFromFirebase(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' => const AttendanceFailure(
        code: AttendanceFailureCode.permissionDenied,
        message: 'No tienes permiso para realizar esta operación.',
      ),
      'unavailable' ||
      'deadline-exceeded' ||
      'aborted' => const AttendanceFailure(
        code: AttendanceFailureCode.unavailable,
        message:
            'No se pudo conectar con Firestore. '
            'El registro de asistencia requiere conexión.',
      ),
      'failed-precondition' => const AttendanceFailure(
        code: AttendanceFailureCode.invalidData,
        message: 'Firestore rechazó el estado de la asistencia.',
      ),
      _ => const AttendanceFailure(
        code: AttendanceFailureCode.unavailable,
        message: 'No se pudo completar la operación de asistencia.',
      ),
    };
  }
}

final class _PreparedAttendanceCommand {
  const _PreparedAttendanceCommand({
    required this.userId,
    required this.attendanceId,
    required this.distanceMeters,
  });

  final String userId;
  final String attendanceId;
  final double distanceMeters;
}
