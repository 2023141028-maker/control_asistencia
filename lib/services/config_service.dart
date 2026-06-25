import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> getOfficeConfig() async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('configuracion')
          .doc('oficina_principal')
          .get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      } else {
        // Si no hay configuración, usamos valores por defecto
        return {
          'latitud': -12.39097,
          'longitud': -74.86005,
          'radio_permitido': 300.0,
        };
      }
    } catch (e) {
      // En caso de error de red, devolvemos valores por defecto
      return {
        'latitud': -12.39097,
        'longitud': -74.86005,
        'radio_permitido': 300.0,
      };
    }
  }
}