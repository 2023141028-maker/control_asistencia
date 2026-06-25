import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Nueva función unificada que recibe todos los datos necesarios
  Future<void> registerAttendance({
    required double latitud,
    required double longitud,
    required String tipo, // 'entrada' o 'salida'
    String modalidad = 'PRESENCIAL', // Nuevo parámetro: REMOTA o PRESENCIAL
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final String fechaHoy = DateTime.now().toString().split(' ')[0];
    final String horaActual = DateTime.now().toString().split(' ')[1].split('.')[0];

    // Si es una ENTRADA, verificamos que no haya una entrada duplicada hoy
    if (tipo == 'entrada') {
      final query = await _firestore
          .collection('asistencia')
          .where('empleado_id', isEqualTo: user.uid)
          .where('fecha', isEqualTo: fechaHoy)
          .get();

      if (query.docs.isNotEmpty) {
        throw Exception('Ya tienes una entrada registrada hoy.');
      }

      // GUARDAR NUEVA ENTRADA (Incluye latitud, longitud y modalidad)
      await _firestore.collection('asistencia').add({
        'empleado_id': user.uid,
        'correo': user.email,
        'fecha': fechaHoy,
        'hora_entrada': horaActual,
        'hora_salida': null,
        'latitud': latitud,
        'longitud': longitud,
        'modalidad': modalidad, // Guardamos si es PRESENCIAL o REMOTA
        'tipo': tipo.toUpperCase(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // Si es una SALIDA, buscamos el registro de entrada de hoy para actualizarlo
    if (tipo == 'salida') {
      final query = await _firestore
          .collection('asistencia')
          .where('empleado_id', isEqualTo: user.uid)
          .where('fecha', isEqualTo: fechaHoy)
          .get();

      if (query.docs.isEmpty) {
        throw Exception('No tienes una entrada registrada hoy. Registra tu entrada primero.');
      }

      // Actualizamos el documento existente agregando la hora de salida y la modalidad de salida
      final docId = query.docs.first.id;
      await _firestore.collection('asistencia').doc(docId).update({
        'hora_salida': horaActual,
        'modalidad_salida': modalidad, // Guardamos cómo salió (PRESENCIAL o REMOTA)
      });
    }
  }
}