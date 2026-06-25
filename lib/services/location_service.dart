import 'package:geolocator/geolocator.dart';
import 'config_service.dart';

class LocationService {
  final ConfigService _configService = ConfigService();

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('GPS desactivado');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Permiso denegado');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso denegado permanentemente');
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // Verifica si está dentro del perímetro leyendo la config de Firestore
  Future<bool> isInsideOffice({required double currentLat, required double currentLon}) async {
    final config = await _configService.getOfficeConfig();

    double officeLat = config['latitud'];
    double officeLon = config['longitud'];
    double allowedRadius = config['radio_permitido'];

    double distance = Geolocator.distanceBetween(currentLat, currentLon, officeLat, officeLon);

    print("📏 Distancia a la oficina: ${distance.toStringAsFixed(0)} metros");
    print("📍 Radio permitido: $allowedRadius metros");

    return distance <= allowedRadius;
  }
}