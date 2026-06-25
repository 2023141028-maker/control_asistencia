import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';  // <--- IMPORTACIÓN ESTÁNDAR
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  // --- GENERAR PDF ---
  Future<Uint8List> _generatePdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Column(
                children: [
                  pw.Text('Reporte de Asistencia', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Usuario: ${_user?.email ?? 'Desconocido'}', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('Fecha de generación: ${DateTime.now().toString().split(' ')[0]}', style: const pw.TextStyle(fontSize: 12)),
                  pw.SizedBox(height: 10),
                  pw.Divider(),
                ],
              ),
            ),
            pw.Table.fromTextArray(
              headers: ['Fecha', 'Entrada', 'Salida', 'Modalidad'],
              data: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return [
                  data['fecha'] ?? '--',
                  data['hora_entrada'] ?? '--:--',
                  data['hora_salida'] ?? 'Pendiente',
                  data['modalidad'] ?? 'PRESENCIAL',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Este reporte fue generado automáticamente por el Sistema de Control de Asistencia.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ];
        },
      ),
    );
    return pdf.save();
  }

  // --- EXPORTAR A CSV (EXCEL) - VERSIÓN 100% ESTABLE ---
  Future<void> _exportToCSV() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('asistencia')
          .where('empleado_id', isEqualTo: _user?.uid)
          .orderBy('fecha', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay datos para exportar.')),
        );
        return;
      }

      // Creamos el contenido CSV manualmente (esto siempre funciona)
      StringBuffer csvContent = StringBuffer();

      // Encabezados
      csvContent.writeln('Fecha,Entrada,Salida,Modalidad');

      // Datos
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String fecha = data['fecha'] ?? '--';
        String entrada = data['hora_entrada'] ?? '--:--';
        String salida = data['hora_salida'] ?? 'Pendiente';
        String modalidad = data['modalidad'] ?? 'PRESENCIAL';

        csvContent.writeln('$fecha,$entrada,$salida,$modalidad');
      }

      // Guardar archivo
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/asistencia.csv';
      final File file = File(path);
      await file.writeAsString(csvContent.toString());

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Reporte de asistencia exportado desde la app.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar CSV: $e')),
      );
    }
  }

  // --- COMPARTIR PDF ---
  Future<void> _sharePdf() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('asistencia')
          .where('empleado_id', isEqualTo: _user?.uid)
          .orderBy('fecha', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay datos para exportar.')),
        );
        return;
      }

      final pdfBytes = await _generatePdf(snapshot.docs);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'reporte_asistencia.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e')),
      );
    }
  }

  // --- VER SELFIE ---
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FutureBuilder<String>(
                    future: FirebaseStorage.instance.refFromURL(imageUrl).getDownloadURL(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 400,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return const SizedBox(
                          height: 400,
                          child: Center(child: Text("Error al cargar la imagen")),
                        );
                      }
                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.contain,
                        height: 400,
                        width: double.infinity,
                      );
                    },
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
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar PDF',
            onPressed: _sharePdf,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0F4FF), Color(0xFFE3EDF7)], // Fondo azul grisáceo suave
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('asistencia')
              .where('empleado_id', isEqualTo: _user?.uid)
              .orderBy('fecha', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 10),
                    Text('Error al cargar: ${snapshot.error}'),
                  ],
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No hay registros de asistencia aún.'));
            }

            final docs = snapshot.data!.docs;

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;

                      final String fecha = data['fecha'] ?? 'Fecha desconocida';
                      final String horaEntrada = data['hora_entrada'] ?? '--:--';
                      final String? horaSalida = data['hora_salida'];
                      final String? urlSelfie = data['url_selfie'];
                      final String? urlSelfieSalida = data['url_selfie_salida'];
                      final String modalidad = data['modalidad'] ?? 'PRESENCIAL';

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 400 + (index * 100)),
                        curve: Curves.easeOutQuart,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(-50 * (1 - value), 0),
                            child: Opacity(
                              opacity: value,
                              child: child,
                            ),
                          );
                        },
                        child: Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      fecha,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: modalidad == 'REMOTA' ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                modalidad == 'REMOTA' ? Icons.home : Icons.business,
                                                size: 14,
                                                color: modalidad == 'REMOTA' ? Colors.orange : Colors.green,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                modalidad == 'REMOTA' ? 'Remoto' : 'Presencial',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: modalidad == 'REMOTA' ? Colors.orange : Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          horaSalida != null ? Icons.check_circle : Icons.access_time,
                                          color: horaSalida != null ? Colors.green : Colors.orange,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.login, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text('Entrada: $horaEntrada', style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.logout, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Salida: ${horaSalida ?? "Pendiente"}',
                                      style: TextStyle(fontSize: 14, color: horaSalida == null ? Colors.orange : Colors.black),
                                    ),
                                  ],
                                ),

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
                        ),
                      );
                    },
                  ),
                ),

                // Botones de exportación
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _sharePdf,
                          icon: const Icon(Icons.share, size: 24),
                          label: const Text(
                            '📤 Compartir mi reporte (PDF)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _exportToCSV,
                          icon: const Icon(Icons.table_chart, size: 24),
                          label: const Text(
                            '📊 Exportar a Excel (CSV)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}