import 'device_location.dart';

enum LocationFailureCode {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  preciseLocationRequired,
  timeout,
  unavailable,
}

abstract interface class LocationService {
  Future<DeviceLocation> getCurrentLocation();

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

class LocationFailure implements Exception {
  const LocationFailure({required this.code, required this.message});

  final LocationFailureCode code;
  final String message;

  @override
  String toString() => message;
}
