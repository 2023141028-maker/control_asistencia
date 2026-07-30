import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/device_location.dart';
import '../domain/location_service.dart';

final class GeolocatorLocationService implements LocationService {
  @override
  Future<DeviceLocation> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw const LocationFailure(
          code: LocationFailureCode.serviceDisabled,
          message: 'El GPS está desactivado.',
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw const LocationFailure(
          code: LocationFailureCode.permissionDenied,
          message: 'El permiso de ubicación fue rechazado.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure(
          code: LocationFailureCode.permissionDeniedForever,
          message: 'El permiso de ubicación está bloqueado permanentemente.',
        );
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const LocationFailure(
          code: LocationFailureCode.unavailable,
          message: 'No se pudo determinar el permiso de ubicación.',
        );
      }

      final accuracyStatus = await Geolocator.getLocationAccuracy();

      if (accuracyStatus == LocationAccuracyStatus.reduced) {
        throw const LocationFailure(
          code: LocationFailureCode.preciseLocationRequired,
          message: 'Activa la ubicación precisa para validar la asistencia.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );

      return DeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
        isMocked: position.isMocked,
      );
    } on LocationFailure {
      rethrow;
    } on TimeoutException {
      throw const LocationFailure(
        code: LocationFailureCode.timeout,
        message:
            'No se obtuvo una ubicación precisa dentro del tiempo esperado.',
      );
    } catch (_) {
      throw const LocationFailure(
        code: LocationFailureCode.unavailable,
        message: 'No se pudo obtener la ubicación actual.',
      );
    }
  }

  @override
  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  @override
  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}
