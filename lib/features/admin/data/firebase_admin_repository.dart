import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../config/firebase_emulator_config.dart';
import '../../attendance/domain/attendance_day.dart';
import '../../attendance/domain/attendance_record.dart';
import '../../offices/domain/office.dart';
import '../../users/domain/user_profile.dart';
import '../domain/admin_repository.dart';

final class FirebaseAdminRepository implements AdminRepository {
  FirebaseAdminRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _users {
    return _firestore.collection('users');
  }

  CollectionReference<Map<String, dynamic>> get _offices {
    return _firestore.collection('offices');
  }

  CollectionReference<Map<String, dynamic>> get _attendances {
    return _firestore.collection('attendances');
  }

  @override
  Stream<List<UserProfile>> watchUsers({int limit = 100}) async* {
    _validateLimit(limit, maximum: 200);

    final query = _users.orderBy('fullName').limit(limit);

    try {
      await for (final snapshot in query.snapshots()) {
        yield snapshot.docs.map(_userFromSnapshot).toList(growable: false);
      }
    } on AdminFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdminFailure(_messageForFirebase(error));
    } catch (_) {
      throw const AdminFailure(
        'No se pudo interpretar la lista de trabajadores.',
      );
    }
  }

  @override
  Stream<List<Office>> watchOffices({int limit = 100}) async* {
    _validateLimit(limit, maximum: 200);

    final query = _offices.orderBy('name').limit(limit);

    try {
      await for (final snapshot in query.snapshots()) {
        yield snapshot.docs.map(_officeFromSnapshot).toList(growable: false);
      }
    } on AdminFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdminFailure(_messageForFirebase(error));
    } catch (_) {
      throw const AdminFailure('No se pudo interpretar la lista de sedes.');
    }
  }

  @override
  Stream<List<AttendanceRecord>> watchRecentAttendances({
    int limit = 50,
  }) async* {
    _validateLimit(limit, maximum: 50);

    final query = _attendances
        .orderBy('workDate', descending: true)
        .limit(limit);

    try {
      await for (final snapshot in query.snapshots()) {
        yield snapshot.docs
            .map(_attendanceFromSnapshot)
            .toList(growable: false);
      }
    } on AdminFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdminFailure(_messageForFirebase(error));
    } catch (_) {
      throw const AdminFailure(
        'No se pudo interpretar la lista de asistencias.',
      );
    }
  }

  @override
  Future<UserProfile> createUser({
    required AdminUserCreateCommand command,
  }) async {
    final email = command.email.trim().toLowerCase();
    final fullName = command.fullName.trim();
    final employeeCode = command.employeeCode.trim().toUpperCase();
    final officeId = _normalizedOfficeId(command.officeId);

    _validateUserFields(
      email: email,
      fullName: fullName,
      employeeCode: employeeCode,
      role: command.role,
      status: command.status,
      officeId: officeId,
    );

    if (command.temporaryPassword.length < 8) {
      throw const AdminFailure(
        'La contraseña temporal debe tener al menos 8 caracteres.',
      );
    }

    FirebaseApp? secondaryApp;
    User? createdAuthUser;

    try {
      final duplicateCode = await _users
          .where('employeeCode', isEqualTo: employeeCode)
          .limit(1)
          .get();

      if (duplicateCode.docs.isNotEmpty) {
        throw const AdminFailure('El código de trabajador ya está registrado.');
      }

      secondaryApp = await Firebase.initializeApp(
        name: 'admin-create-${DateTime.now().microsecondsSinceEpoch}',
        options: Firebase.app().options,
      );

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      if (FirebaseEmulatorConfig.enabled) {
        await secondaryAuth.useAuthEmulator(
          FirebaseEmulatorConfig.host,
          9099,
          automaticHostMapping: false,
        );
      }

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: command.temporaryPassword,
      );

      createdAuthUser = credential.user;

      if (createdAuthUser == null) {
        throw const AdminFailure(
          'Authentication no devolvió el nuevo usuario.',
        );
      }

      final reference = _users.doc(createdAuthUser.uid);

      await reference.set({
        'uid': createdAuthUser.uid,
        'email': email,
        'fullName': fullName,
        'employeeCode': employeeCode,
        'role': _roleValue(command.role),
        'status': _statusValue(command.status),
        'officeId': officeId,
        'schemaVersion': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final snapshot = await reference.get(
        const GetOptions(source: Source.server),
      );

      return _userFromSnapshot(snapshot);
    } on AdminFailure {
      await _deleteCreatedAuthUser(createdAuthUser);
      rethrow;
    } on FirebaseAuthException catch (error) {
      await _deleteCreatedAuthUser(createdAuthUser);
      throw AdminFailure(_messageForAuth(error));
    } on FirebaseException catch (error) {
      await _deleteCreatedAuthUser(createdAuthUser);
      throw AdminFailure(_messageForFirebase(error));
    } catch (_) {
      await _deleteCreatedAuthUser(createdAuthUser);
      throw const AdminFailure(
        'No se pudo registrar la cuenta del trabajador.',
      );
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
    }
  }

  @override
  Future<void> updateUser({required AdminUserUpdateCommand command}) async {
    final uid = command.uid.trim();
    final fullName = command.fullName.trim();
    final employeeCode = command.employeeCode.trim().toUpperCase();
    final officeId = _normalizedOfficeId(command.officeId);

    if (uid.isEmpty || uid.contains('/')) {
      throw const AdminFailure('El UID del trabajador no es válido.');
    }

    _validateUserFields(
      email: 'existing@profile.local',
      fullName: fullName,
      employeeCode: employeeCode,
      role: command.role,
      status: command.status,
      officeId: officeId,
    );

    try {
      final duplicateCode = await _users
          .where('employeeCode', isEqualTo: employeeCode)
          .limit(2)
          .get();

      final usedByAnotherUser = duplicateCode.docs.any(
        (document) => document.id != uid,
      );

      if (usedByAnotherUser) {
        throw const AdminFailure(
          'El código de trabajador pertenece a otra cuenta.',
        );
      }

      await _users.doc(uid).update({
        'fullName': fullName,
        'employeeCode': employeeCode,
        'role': _roleValue(command.role),
        'status': _statusValue(command.status),
        'officeId': officeId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on AdminFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdminFailure(_messageForFirebase(error));
    } catch (_) {
      throw const AdminFailure(
        'No se pudo actualizar el perfil del trabajador.',
      );
    }
  }

  @override
  Future<Office> saveOffice({required AdminOfficeSaveCommand command}) async {
    final id = command.id.trim().toLowerCase();
    final name = command.name.trim();
    final address = command.address.trim();

    _validateOfficeFields(
      id: id,
      name: name,
      address: address,
      latitude: command.latitude,
      longitude: command.longitude,
      radiusMeters: command.radiusMeters,
      maxAccuracyMeters: command.maxAccuracyMeters,
    );

    final reference = _offices.doc(id);

    try {
      if (command.isNew) {
        final existing = await reference.get();

        if (existing.exists) {
          throw const AdminFailure('Ya existe una sede con ese identificador.');
        }

        await reference.set({
          'name': name,
          'address': address,
          'location': GeoPoint(command.latitude, command.longitude),
          'radiusMeters': command.radiusMeters,
          'maxAccuracyMeters': command.maxAccuracyMeters,
          'timezone': 'America/Lima',
          'active': command.active,
          'schemaVersion': 1,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await reference.update({
          'name': name,
          'address': address,
          'location': GeoPoint(command.latitude, command.longitude),
          'radiusMeters': command.radiusMeters,
          'maxAccuracyMeters': command.maxAccuracyMeters,
          'timezone': 'America/Lima',
          'active': command.active,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final snapshot = await reference.get(
        const GetOptions(source: Source.server),
      );

      return _officeFromSnapshot(snapshot);
    } on AdminFailure {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdminFailure(_messageForFirebase(error));
    } catch (_) {
      throw const AdminFailure('No se pudo guardar la sede.');
    }
  }

  @override
  Future<String> getEvidenceDownloadUrl({required String evidencePath}) async {
    final path = evidencePath.trim();

    if (!path.startsWith('attendanceEvidence/') || !path.endsWith('.jpg')) {
      throw const AdminFailure('La ruta de evidencia no es válida.');
    }

    try {
      return await _storage.ref(path).getDownloadURL();
    } on FirebaseException catch (error) {
      throw AdminFailure(_messageForFirebase(error));
    } catch (_) {
      throw const AdminFailure('No se pudo abrir la evidencia fotográfica.');
    }
  }

  Future<void> _deleteCreatedAuthUser(User? user) async {
    if (user == null) {
      return;
    }

    try {
      await user.delete();
    } catch (_) {
      // La creación del perfil conserva el error original.
    }
  }

  UserProfile _userFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw const AdminFailure('El perfil solicitado no existe.');
    }

    final user = UserProfile(
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

    if (user.uid != snapshot.id || user.schemaVersion != 1) {
      throw const AdminFailure('El perfil tiene una estructura incompatible.');
    }

    return user;
  }

  Office _officeFromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw const AdminFailure('La sede solicitada no existe.');
    }

    final location = _requiredGeoPoint(data, 'location');

    final office = Office(
      id: snapshot.id,
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

    if (office.schemaVersion != 1 || office.timezone != 'America/Lima') {
      throw const AdminFailure('La sede tiene una estructura incompatible.');
    }

    return office;
  }

  AttendanceRecord _attendanceFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      throw const AdminFailure('La asistencia solicitada no existe.');
    }

    final checkIn = _attendanceMarkFromMap(_requiredMap(data, 'checkIn'));

    final checkOutValue = data['checkOut'];

    final record = AttendanceRecord(
      id: snapshot.id,
      userId: _requiredString(data, 'userId'),
      officeId: _requiredString(data, 'officeId'),
      workDay: AttendanceDay.parse(_requiredString(data, 'workDate')),
      mode: _attendanceModeFromValue(data['mode']),
      status: _attendanceStatusFromValue(data['status']),
      checkIn: checkIn,
      checkOut: checkOutValue == null
          ? null
          : _attendanceMarkFromMap(_mapFromValue(checkOutValue, 'checkOut')),
      schemaVersion: _requiredInt(data, 'schemaVersion'),
      createdAt: _requiredTimestamp(data, 'createdAt').toDate(),
      updatedAt: _requiredTimestamp(data, 'updatedAt').toDate(),
    );

    if (record.schemaVersion != 1 ||
        record.workDay.documentIdFor(record.userId) != record.id) {
      throw const AdminFailure(
        'La asistencia tiene una estructura incompatible.',
      );
    }

    return record;
  }

  AttendanceMark _attendanceMarkFromMap(Map<String, dynamic> data) {
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

  void _validateLimit(int limit, {required int maximum}) {
    if (limit < 1 || limit > maximum) {
      throw AdminFailure('El límite debe estar entre 1 y $maximum.');
    }
  }

  void _validateUserFields({
    required String email,
    required String fullName,
    required String employeeCode,
    required UserRole role,
    required UserStatus status,
    required String? officeId,
  }) {
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const AdminFailure('El correo electrónico no es válido.');
    }

    if (fullName.length < 3 || fullName.length > 100) {
      throw const AdminFailure(
        'El nombre debe tener entre 3 y 100 caracteres.',
      );
    }

    if (employeeCode.length < 3 || employeeCode.length > 30) {
      throw const AdminFailure('El código debe tener entre 3 y 30 caracteres.');
    }

    if (role == UserRole.employee &&
        status == UserStatus.active &&
        officeId == null) {
      throw const AdminFailure(
        'Un trabajador activo debe tener una sede asignada.',
      );
    }
  }

  void _validateOfficeFields({
    required String id,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required double maxAccuracyMeters,
  }) {
    if (!RegExp(r'^[a-z0-9-]{3,50}$').hasMatch(id)) {
      throw const AdminFailure(
        'El identificador debe usar minúsculas, números y guiones.',
      );
    }

    if (name.length < 3 || name.length > 100) {
      throw const AdminFailure(
        'El nombre de sede debe tener entre 3 y 100 caracteres.',
      );
    }

    if (address.length < 5 || address.length > 200) {
      throw const AdminFailure(
        'La dirección debe tener entre 5 y 200 caracteres.',
      );
    }

    if (latitude < -90 || latitude > 90) {
      throw const AdminFailure('La latitud debe estar entre -90 y 90.');
    }

    if (longitude < -180 || longitude > 180) {
      throw const AdminFailure('La longitud debe estar entre -180 y 180.');
    }

    if (radiusMeters < 20 || radiusMeters > 500) {
      throw const AdminFailure(
        'El radio permitido debe estar entre 20 y 500 metros.',
      );
    }

    if (maxAccuracyMeters < 5 || maxAccuracyMeters > 100) {
      throw const AdminFailure(
        'La precisión máxima debe estar entre 5 y 100 metros.',
      );
    }
  }

  String? _normalizedOfficeId(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String _requiredString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw AdminFailure('El campo $field no es válido.');
  }

  String? _nullableString(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value == null) {
      return null;
    }

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    throw AdminFailure('El campo $field no es válido.');
  }

  int _requiredInt(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is int) {
      return value;
    }

    throw AdminFailure('El campo $field no es válido.');
  }

  double _requiredNumber(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is num) {
      return value.toDouble();
    }

    throw AdminFailure('El campo $field no es válido.');
  }

  bool _requiredBool(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is bool) {
      return value;
    }

    throw AdminFailure('El campo $field no es válido.');
  }

  Timestamp _requiredTimestamp(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is Timestamp) {
      return value;
    }

    throw AdminFailure('El campo $field no es válido.');
  }

  GeoPoint _requiredGeoPoint(Map<String, dynamic> data, String field) {
    final value = data[field];

    if (value is GeoPoint) {
      return value;
    }

    throw AdminFailure('El campo $field no es un GeoPoint válido.');
  }

  Map<String, dynamic> _requiredMap(Map<String, dynamic> data, String field) {
    return _mapFromValue(data[field], field);
  }

  Map<String, dynamic> _mapFromValue(Object? value, String field) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(key.toString(), nestedValue),
      );
    }

    throw AdminFailure('El campo $field no es un mapa válido.');
  }

  UserRole _roleFromValue(Object? value) {
    return switch (value) {
      'admin' => UserRole.admin,
      'employee' => UserRole.employee,
      _ => throw const AdminFailure('El rol no es válido.'),
    };
  }

  UserStatus _statusFromValue(Object? value) {
    return switch (value) {
      'active' => UserStatus.active,
      'inactive' => UserStatus.inactive,
      'pending' => UserStatus.pending,
      _ => throw const AdminFailure('El estado no es válido.'),
    };
  }

  AttendanceMode _attendanceModeFromValue(Object? value) {
    return switch (value) {
      'onsite' => AttendanceMode.onsite,
      _ => throw const AdminFailure('El modo de asistencia no es válido.'),
    };
  }

  AttendanceStatus _attendanceStatusFromValue(Object? value) {
    return switch (value) {
      'checked-in' => AttendanceStatus.checkedIn,
      'completed' => AttendanceStatus.completed,
      _ => throw const AdminFailure('El estado de asistencia no es válido.'),
    };
  }

  String _roleValue(UserRole role) {
    return switch (role) {
      UserRole.admin => 'admin',
      UserRole.employee => 'employee',
    };
  }

  String _statusValue(UserStatus status) {
    return switch (status) {
      UserStatus.active => 'active',
      UserStatus.inactive => 'inactive',
      UserStatus.pending => 'pending',
    };
  }

  String _messageForAuth(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'El correo ya tiene una cuenta.',
      'invalid-email' => 'El correo electrónico no es válido.',
      'weak-password' => 'La contraseña temporal no es suficientemente segura.',
      'operation-not-allowed' =>
        'El registro con correo y contraseña no está habilitado.',
      'network-request-failed' =>
        'No se pudo conectar con Firebase Authentication.',
      _ => 'No se pudo crear la cuenta de Authentication.',
    };
  }

  String _messageForFirebase(FirebaseException error) {
    return switch (error.code) {
      'permission-denied' =>
        'No tienes permisos administrativos para esta operación.',
      'not-found' => 'El registro solicitado no existe.',
      'already-exists' => 'El registro ya existe.',
      'unavailable' => 'Firebase no está disponible temporalmente.',
      'failed-precondition' =>
        'La operación requiere una configuración adicional de Firebase.',
      _ => 'Firebase rechazó la operación (${error.code}).',
    };
  }
}
