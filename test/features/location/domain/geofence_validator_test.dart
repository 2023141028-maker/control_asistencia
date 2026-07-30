import 'package:control_asistencia/features/location/domain/device_location.dart';
import 'package:control_asistencia/features/location/domain/geofence_validator.dart';
import 'package:control_asistencia/features/offices/domain/office.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeofenceValidator', () {
    test('acepta una ubicación precisa dentro de la sede', () {
      final result = const GeofenceValidator().validate(
        office: _office(),
        location: _location(),
      );

      expect(result.status, GeofenceStatus.allowed);
      expect(result.isAllowed, isTrue);
      expect(result.distanceMeters, closeTo(0, 0.01));
    });

    test('rechaza una ubicación fuera del radio permitido', () {
      final result = const GeofenceValidator().validate(
        office: _office(),
        location: _location(latitude: -12.387037),
      );

      expect(result.status, GeofenceStatus.outsideRadius);
      expect(result.distanceMeters, greaterThan(100));
    });

    test('rechaza una precisión superior a 30 metros', () {
      final result = const GeofenceValidator().validate(
        office: _office(),
        location: _location(accuracyMeters: 45),
      );

      expect(result.status, GeofenceStatus.lowAccuracy);
      expect(result.isAllowed, isFalse);
    });

    test('rechaza una ubicación simulada en producción', () {
      final result = const GeofenceValidator().validate(
        office: _office(),
        location: _location(isMocked: true),
      );

      expect(result.status, GeofenceStatus.mockedLocation);
    });

    test('permite una ubicación simulada solo para desarrollo', () {
      final result = const GeofenceValidator(
        allowMockedLocations: true,
      ).validate(office: _office(), location: _location(isMocked: true));

      expect(result.status, GeofenceStatus.allowed);
    });
  });
}

Office _office() {
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

DeviceLocation _location({
  double latitude = -12.389037,
  double longitude = -74.858949,
  double accuracyMeters = 10,
  bool isMocked = false,
}) {
  return DeviceLocation(
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: accuracyMeters,
    capturedAt: DateTime.utc(2026, 7, 29),
    isMocked: isMocked,
  );
}
