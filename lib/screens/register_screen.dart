import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/attendance_service.dart';
import '../services/location_service.dart';

class RegisterScreen extends StatefulWidget {
  final String tipo;
  final bool isRemoteMode;

  const RegisterScreen({
    super.key,
    required this.tipo,
    required this.isRemoteMode,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final LocationService _locationService = LocationService();
  bool _isLoading = false;

  // Definimos los colores según el tipo (Entrada o Salida)
  Color get _primaryColor => widget.tipo == 'entrada' ? const Color(0xFF4A90E2) : const Color(0xFFF57C00);
  Color get _secondaryColor => widget.tipo == 'entrada' ? const Color(0xFF1E3A8A) : const Color(0xFFE65100);
  List<Color> get _gradientColors => widget.tipo == 'entrada'
      ? [const Color(0xFFE3F2FD), const Color(0xFFBBDEFB)]
      : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)];

  Future<String> _getUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Usuario';
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['nombre'] ?? 'Usuario';
      }
      return 'Usuario';
    } catch (e) {
      return 'Usuario';
    }
  }

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
                    backgroundColor: _secondaryColor,
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

  Future<void> _handleRegister() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Color(0xFF1E3A8A), strokeWidth: 4)),
                const SizedBox(height: 15),
                const Text("Validando ubicación y preparando cámara...", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
              ],
            ),
          ),
        );
      },
    );

    try {
      double? latitud; double? longitud; String modalidad;
      if (!widget.isRemoteMode) {
        Position position = await _getCurrentLocation();
        latitud = position.latitude; longitud = position.longitude;
        bool isInside = await _locationService.isInsideOffice(currentLat: position.latitude, currentLon: position.longitude);
        if (!isInside) throw Exception('⛔ Fuera del perímetro autorizado. Activa el modo remoto en el inicio.');
        modalidad = 'PRESENCIAL';
      } else {
        latitud = 0.0; longitud = 0.0; modalidad = 'REMOTA';
      }

      if (mounted) Navigator.pop(context);
      XFile? selfie = await _takeSelfie();
      if (selfie == null) throw Exception('No se tomó la foto.');
      await _attendanceService.registerAttendance(latitud: latitud, longitud: longitud, tipo: widget.tipo);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${widget.tipo.toUpperCase()} registrada ($modalidad)'), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $e'), backgroundColor: Colors.red));
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
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _gradientColors,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<String>(
                future: _getUserName(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text("¡Hola, ${snapshot.data}! 👋", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87));
                  } else {
                    return const Text("¡Hola! 👋", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87));
                  }
                },
              ),
              const SizedBox(height: 5),
              Text("Confirma tu ${widget.tipo} con reconocimiento facial", style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 30),

              // Tarjeta con fondo blanco para que resalte el botón
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: _buildOptionCard(
                  icon: Icons.face,
                  title: "Reconocimiento Facial",
                  subtitle: "Verificaremos tu rostro para registrar tu ${widget.tipo}",
                  color: _primaryColor.withOpacity(0.1),
                  iconColor: _primaryColor,
                  onTap: _handleRegister,
                ),
              ),

              const Spacer(),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _secondaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.isRemoteMode
                            ? "Modo Fuera de Oficina activado. No se validará el GPS."
                            : "Debes estar a menos del radio permitido para registrar tu asistencia.",
                        style: TextStyle(color: _secondaryColor, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
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