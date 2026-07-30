import 'dart:math' as math;

import '../../offices/domain/office.dart';
import 'device_location.dart';

enum GeofenceStatus {
  allowed,
  outsideRadius,
  lowAccuracy,
  mockedLocation,
  inactiveOffice,
}

class GeofenceValidationResult {
  const GeofenceValidationResult({
    required this.status,
    required this.distanceMeters,
    required this.accuracyMeters,
  });

  final GeofenceStatus status;
  final double distanceMeters;
  final double accuracyMeters;

  bool get isAllowed => status == GeofenceStatus.allowed;

  String get message => switch (status) {
    GeofenceStatus.allowed => 'Ubicación validada correctamente.',
    GeofenceStatus.outsideRadius => 'Te encuentras fuera del radio permitido.',
    GeofenceStatus.lowAccuracy => 'La precisión del GPS no es suficiente.',
    GeofenceStatus.mockedLocation => 'Se detectó una ubicación simulada.',
    GeofenceStatus.inactiveOffice => 'La sede asignada está inactiva.',
  };
}

final class GeofenceValidator {
  const GeofenceValidator({this.allowMockedLocations = false});

  final bool allowMockedLocations;

  GeofenceValidationResult validate({
    required Office office,
    required DeviceLocation location,
  }) {
    final distance = distanceBetween(
      startLatitude: office.latitude,
      startLongitude: office.longitude,
      endLatitude: location.latitude,
      endLongitude: location.longitude,
    );

    if (!office.active) {
      return GeofenceValidationResult(
        status: GeofenceStatus.inactiveOffice,
        distanceMeters: distance,
        accuracyMeters: location.accuracyMeters,
      );
    }

    if (location.isMocked && !allowMockedLocations) {
      return GeofenceValidationResult(
        status: GeofenceStatus.mockedLocation,
        distanceMeters: distance,
        accuracyMeters: location.accuracyMeters,
      );
    }

    if (location.accuracyMeters <= 0 ||
        location.accuracyMeters > office.maxAccuracyMeters) {
      return GeofenceValidationResult(
        status: GeofenceStatus.lowAccuracy,
        distanceMeters: distance,
        accuracyMeters: location.accuracyMeters,
      );
    }

    if (distance > office.radiusMeters) {
      return GeofenceValidationResult(
        status: GeofenceStatus.outsideRadius,
        distanceMeters: distance,
        accuracyMeters: location.accuracyMeters,
      );
    }

    return GeofenceValidationResult(
      status: GeofenceStatus.allowed,
      distanceMeters: distance,
      accuracyMeters: location.accuracyMeters,
    );
  }

  double distanceBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const earthRadiusMeters = 6371008.8;

    final latitudeDelta = _toRadians(endLatitude - startLatitude);
    final longitudeDelta = _toRadians(endLongitude - startLongitude);

    final startLatitudeRadians = _toRadians(startLatitude);
    final endLatitudeRadians = _toRadians(endLatitude);

    final haversine =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(startLatitudeRadians) *
            math.cos(endLatitudeRadians) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);

    final normalizedHaversine = haversine.clamp(0.0, 1.0).toDouble();

    final angularDistance =
        2 *
        math.atan2(
          math.sqrt(normalizedHaversine),
          math.sqrt(1 - normalizedHaversine),
        );

    return earthRadiusMeters * angularDistance;
  }

  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }
}
