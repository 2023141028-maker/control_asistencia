import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

final class FirebaseEmulatorConfig {
  FirebaseEmulatorConfig._();

  static const bool enabled = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );

  static const String host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  static Future<void> connectIfEnabled() async {
    if (!enabled) {
      return;
    }

    final firestore = FirebaseFirestore.instance;

    firestore.settings = const Settings(persistenceEnabled: false);

    firestore.useFirestoreEmulator(host, 8080, automaticHostMapping: false);

    final auth = FirebaseAuth.instance;

    await auth.useAuthEmulator(host, 9099, automaticHostMapping: false);

    await FirebaseStorage.instance.useStorageEmulator(
      host,
      9199,
      automaticHostMapping: false,
    );

    // Evita reutilizar accidentalmente una sesión de producción.
    await auth.signOut();

    debugPrint(
      'Firebase Emulator Suite conectado en $host '
      '(Auth 9099, Firestore 8080, Storage 9199).',
    );
  }
}
