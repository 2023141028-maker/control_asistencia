import 'dart:typed_data';

import 'package:control_asistencia/features/attendance/domain/attendance_day.dart';
import 'package:control_asistencia/features/evidence/domain/attendance_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EvidencePolicy', () {
    final workDay = AttendanceDay.parse('2026-07-30');

    test('construye la ruta exacta de entrada', () {
      final path = EvidencePolicy.pathFor(
        userId: 'employee-001',
        workDay: workDay,
        event: EvidenceEvent.checkIn,
      );

      expect(
        path,
        'attendanceEvidence/'
        'employee-001/'
        'employee-001_2026-07-30/'
        'check-in.jpg',
      );
    });

    test('construye la ruta exacta de salida', () {
      final path = EvidencePolicy.pathFor(
        userId: 'employee-001',
        workDay: workDay,
        event: EvidenceEvent.checkOut,
      );

      expect(
        path,
        'attendanceEvidence/'
        'employee-001/'
        'employee-001_2026-07-30/'
        'check-out.jpg',
      );
    });

    test('acepta una evidencia JPEG válida', () {
      final evidence = CapturedEvidence(
        bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]),
        capturedAt: DateTime.utc(2026, 7, 30, 13),
      );

      expect(
        () => EvidencePolicy.validateCapturedEvidence(evidence),
        returnsNormally,
      );
    });

    test('rechaza una evidencia vacía', () {
      final evidence = CapturedEvidence(
        bytes: Uint8List(0),
        capturedAt: DateTime.utc(2026, 7, 30, 13),
      );

      expect(
        () => EvidencePolicy.validateCapturedEvidence(evidence),
        throwsA(
          isA<EvidenceFailure>().having(
            (failure) => failure.code,
            'code',
            EvidenceFailureCode.emptyFile,
          ),
        ),
      );
    });

    test('rechaza un archivo que no es JPEG', () {
      final evidence = CapturedEvidence(
        bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        capturedAt: DateTime.utc(2026, 7, 30, 13),
      );

      expect(
        () => EvidencePolicy.validateCapturedEvidence(evidence),
        throwsA(
          isA<EvidenceFailure>().having(
            (failure) => failure.code,
            'code',
            EvidenceFailureCode.invalidFormat,
          ),
        ),
      );
    });

    test('rechaza una evidencia mayor de 2 MB', () {
      final bytes = Uint8List(EvidencePolicy.maxSizeBytes + 1);

      bytes[0] = 0xFF;
      bytes[1] = 0xD8;
      bytes[2] = 0xFF;

      final evidence = CapturedEvidence(
        bytes: bytes,
        capturedAt: DateTime.utc(2026, 7, 30, 13),
      );

      expect(
        () => EvidencePolicy.validateCapturedEvidence(evidence),
        throwsA(
          isA<EvidenceFailure>().having(
            (failure) => failure.code,
            'code',
            EvidenceFailureCode.fileTooLarge,
          ),
        ),
      );
    });

    test('rechaza un UID que contiene una barra', () {
      expect(
        () => EvidencePolicy.pathFor(
          userId: 'employee/001',
          workDay: workDay,
          event: EvidenceEvent.checkIn,
        ),
        throwsA(
          isA<EvidenceFailure>().having(
            (failure) => failure.code,
            'code',
            EvidenceFailureCode.invalidData,
          ),
        ),
      );
    });
  });
}
