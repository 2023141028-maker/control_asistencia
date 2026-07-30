import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'config/firebase_emulator_config.dart';
import 'features/auth/data/firebase_auth_repository.dart';
import 'features/offices/data/firestore_office_repository.dart';
import 'features/users/data/firestore_user_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseEmulatorConfig.connectIfEnabled();

  runApp(
    AttendanceApp(
      authRepository: FirebaseAuthRepository(),
      userRepository: FirestoreUserRepository(),
      officeRepository: FirestoreOfficeRepository(),
    ),
  );
}
