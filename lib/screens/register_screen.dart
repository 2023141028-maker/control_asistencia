import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import '../services/attendance_service.dart'; // Importamos el servicio

class RegisterScreen extends StatefulWidget {
  final String tipo; // Recibimos si es 'entrada' o 'salida'
  const RegisterScreen({super.key, required this.tipo});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  bool _isLoading = false;

  // Obtener GPS
  Future<Position> _getCurrentLocation() async {
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

  // Abrir cámara y tomar selfie
  Future<XFile?> _takeSelfie() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();

      if (!mounted) return null;
      final XFile? photo = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Stack(
            children: [
              Center(child: CameraPreview(controller)),
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.large(
                    onPressed: () async {
                      final XFile image = await controller.takePicture();
                      if (mounted) Navigator.pop(context, image);
                    },
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      controller.dispose();
      return photo;
    } catch (e) {
      return null;
    }
  }

  // Lógica principal
  Future<void> _handleRegister() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      // 1. GPS
      Position position = await _getCurrentLocation();

      // 2. Validar 300m
      double officeLat = -12.39097; // CÁMBIALO
      double officeLon = -74.86005; // CÁMBIALO
      double distance = Geolocator.distanceBetween(
          position.latitude, position.longitude, officeLat, officeLon);
      if (distance > 300) {
        throw Exception('⛔ Fuera del perímetro (${distance.toStringAsFixed(0)}m).');
      }

      // 3. Selfie
      XFile? selfie = await _takeSelfie();
      if (selfie == null) throw Exception('No se tomó la foto.');

      // 4. Guardar usando el Servicio (Entrada o Salida)
      await _attendanceService.registerAttendance(
        latitud: position.latitude,
        longitud: position.longitude,
        tipo: widget.tipo,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ${widget.tipo.toUpperCase()} registrada'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Registrar ${widget.tipo.toUpperCase()}"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("¡Hola, Juan! 👋", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("Confirma tu ${widget.tipo} con reconocimiento facial", style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 30),

            _buildOptionCard(
              icon: Icons.face,
              title: "Reconocimiento Facial",
              subtitle: "Verificaremos tu rostro para registrar tu ${widget.tipo}",
              color: const Color(0xFFE3F2FD),
              iconColor: Colors.blue,
              onTap: _handleRegister,
            ),

            const Spacer(),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Debes estar a menos de 300 metros de la oficina para registrar tu asistencia.",
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}