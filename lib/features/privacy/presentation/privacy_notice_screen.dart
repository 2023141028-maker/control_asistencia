import 'package:flutter/material.dart';

import '../domain/privacy_policy.dart';

class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y evidencias')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const _NoticeSection(
              icon: Icons.fact_check_outlined,
              title: 'Finalidad',
              body:
                  'La fotografía, la plantilla facial y la ubicación se usan '
                  'únicamente para verificar la identidad y la presencia en '
                  'la sede al registrar una entrada o salida.',
            ),
            const _NoticeSection(
              icon: Icons.data_saver_on_outlined,
              title: 'Datos mínimos utilizados',
              body:
                  'Identificador de cuenta, sede, fecha y hora, ubicación '
                  'validada, evidencia fotográfica y plantilla numérica del '
                  'rostro. La aplicación no solicita DNI, datos financieros '
                  'ni información tributaria.',
            ),
            _NoticeSection(
              icon: Icons.event_busy_outlined,
              title: 'Conservación',
              body:
                  'Cada evidencia recibe una fecha límite de conservación de '
                  '${PrivacyPolicy.evidenceRetentionDays} días. Después debe '
                  'ser eliminada mediante un proceso administrativo '
                  'autorizado. Los metadatos de asistencia se conservan para '
                  'la trazabilidad laboral.',
            ),
            const _NoticeSection(
              icon: Icons.lock_outline,
              title: 'Protección',
              body:
                  'Firestore almacena la asistencia y la referencia de la '
                  'evidencia; Cloudinary almacena la fotografía. La clave '
                  'secreta de Cloudinary no se incluye en la aplicación y '
                  'cada usuario solo consulta sus propios registros.',
            ),
            const _NoticeSection(
              icon: Icons.manage_accounts_outlined,
              title: 'Control del trabajador',
              body:
                  'Antes de cada marcación se solicita una aceptación '
                  'expresa. Para retirar el consentimiento, solicitar la '
                  'desactivación de la plantilla facial o consultar una '
                  'evidencia, el trabajador debe comunicarse con el '
                  'administrador responsable.',
            ),
            const SizedBox(height: 12),
            Text(
              'Aviso de privacidad v${PrivacyPolicy.noticeVersion} · '
              'Política de conservación '
              'v${PrivacyPolicy.retentionPolicyVersion}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeSection extends StatelessWidget {
  const _NoticeSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colors.primaryContainer,
              child: Icon(icon, color: colors.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
