import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  // Función para abrir el visor de imágenes
  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Evidencia (Selfie)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),

                // Versión CORREGIDA: Usamos Image.network directamente
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.grey[100],
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      height: 400,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                              SizedBox(height: 10),
                              Text("Error al cargar la imagen"),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Asistencia'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('asistencia')
            .where('empleado_id', isEqualTo: _user?.uid)
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Estado de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Si hay un error
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 10),
                  Text('Error al cargar: ${snapshot.error}'),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text("Reintentar"),
                  ),
                ],
              ),
            );
          }

          // Si no hay datos
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay registros de asistencia aún.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              // Leer datos de forma segura
              final String fecha = data['fecha'] ?? 'Fecha desconocida';
              final String horaEntrada = data['hora_entrada'] ?? '--:--';
              final String? horaSalida = data['hora_salida'];
              final String? urlSelfie = data['url_selfie'];
              final String? urlSelfieSalida = data['url_selfie_salida'];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fecha
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            fecha,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Icon(
                            horaSalida != null ? Icons.check_circle : Icons.access_time,
                            color: horaSalida != null ? Colors.green : Colors.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Entrada
                      Row(
                        children: [
                          const Icon(Icons.login, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Entrada: $horaEntrada',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Salida
                      Row(
                        children: [
                          const Icon(Icons.logout, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Salida: ${horaSalida ?? "Pendiente"}',
                            style: TextStyle(
                              fontSize: 14,
                              color: horaSalida == null ? Colors.orange : Colors.black,
                            ),
                          ),
                        ],
                      ),

                      // BOTÓN PARA VER LA EVIDENCIA (Selfie de Entrada)
                      if (urlSelfie != null) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () => _showImageDialog(urlSelfie),
                            icon: const Icon(Icons.image),
                            label: const Text("Ver selfie de Entrada"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade100,
                              foregroundColor: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],

                      // BOTÓN PARA VER LA EVIDENCIA (Selfie de Salida)
                      if (urlSelfieSalida != null) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () => _showImageDialog(urlSelfieSalida),
                            icon: const Icon(Icons.image),
                            label: const Text("Ver selfie de Salida"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade100,
                              foregroundColor: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}