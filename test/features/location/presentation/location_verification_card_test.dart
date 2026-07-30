import 'package:control_asistencia/features/location/domain/device_location.dart';
import 'package:control_asistencia/features/location/domain/geofence_validator.dart';
import 'package:control_asistencia/features/location/domain/location_service.dart';
import 'package:control_asistencia/features/location/presentation/location_verification_card.dart';
import 'package:control_asistencia/features/offices/domain/office.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeLocationService implements LocationService {
  FakeLocationService(this.location);

  final DeviceLocation location;

  @override
  Future<DeviceLocation> getCurrentLocation() async {
    return location;
  }

  @override
  Future<bool> openAppSettings() async {
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    return true;
  }
}

void main() {
  testWidgets('muestra ubicación permitida dentro del radio', (tester) async {
    final office = _buildOffice();

    final location = DeviceLocation(
      latitude: office.latitude,
      longitude: office.longitude,
      accuracyMeters: 5,
      capturedAt: DateTime.utc(2026, 7, 29, 15),
      isMocked: false,
    );

    await tester.pumpWidget(_buildTestApp(office: office, location: location));

    await tester.tap(find.text('Verificar ubicación'));
    await tester.pumpAndSettle();

    expect(find.text('Ubicación validada correctamente.'), findsOneWidget);
    expect(find.text('UBICACIÓN PERMITIDA'), findsOneWidget);
    expect(find.text('0.0 m'), findsOneWidget);
  });

  testWidgets('muestra rechazo cuando está fuera del radio', (tester) async {
    final office = _buildOffice();

    final location = DeviceLocation(
      latitude: -12.387037,
      longitude: office.longitude,
      accuracyMeters: 5,
      capturedAt: DateTime.utc(2026, 7, 29, 15),
      isMocked: false,
    );

    await tester.pumpWidget(_buildTestApp(office: office, location: location));

    await tester.tap(find.text('Verificar ubicación'));
    await tester.pumpAndSettle();

    expect(
      find.text('Te encuentras fuera del radio permitido.'),
      findsOneWidget,
    );
    expect(find.text('UBICACIÓN NO PERMITIDA'), findsOneWidget);
  });
}

Widget _buildTestApp({
  required Office office,
  required DeviceLocation location,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LocationVerificationCard(
          office: office,
          locationService: FakeLocationService(location),
          geofenceValidator: const GeofenceValidator(),
        ),
      ),
    ),
  );
}

Office _buildOffice() {
  return Office(
    id: 'unh-pampas',
    name: 'UNH sede Pampas',
    address: 'Av. Perú, Daniel Hernández 09161',
    latitude: -12.389037,
    longitude: -74.858949,
    radiusMeters: 100,
    maxAccuracyMeters: 30,
    timezone: 'America/Lima',
    active: true,
    schemaVersion: 1,
    createdAt: DateTime.utc(2026, 7, 29),
    updatedAt: DateTime.utc(2026, 7, 29),
  );
}
