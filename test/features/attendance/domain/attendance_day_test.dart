import 'package:control_asistencia/features/attendance/domain/attendance_day.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:control_asistencia/features/users/domain/hospital_assignment.dart';

void main() {
  group('AttendanceDay', () {
    test('usa el día anterior antes de medianoche en Lima', () {
      final instant = DateTime.utc(2026, 7, 30, 4, 59, 59);

      final workDay = AttendanceDay.fromInstant(instant);

      expect(workDay.value, '2026-07-29');
    });

    test('cambia de día exactamente a medianoche en Lima', () {
      final instant = DateTime.utc(2026, 7, 30, 5);

      final workDay = AttendanceDay.fromInstant(instant);

      expect(workDay.value, '2026-07-30');
    });

    test('construye un identificador determinista', () {
      final workDay = AttendanceDay.parse('2026-07-30');

      final documentId = workDay.documentIdFor('usuario-123');

      expect(documentId, 'usuario-123_2026-07-30');
    });

    test('mantiene la jornada nocturna después de medianoche', () {
      // 06:30 en Lima del 31/07 pertenece al turno iniciado el 30/07.
      final instant = DateTime.utc(2026, 7, 31, 11, 30);

      final workDay = AttendanceDay.forShift(instant, HospitalShift.night);

      expect(workDay.value, '2026-07-30');
    });

    test('inicia una nueva jornada nocturna después de las 07:00', () {
      // 19:15 en Lima inicia la jornada nocturna del mismo día.
      final instant = DateTime.utc(2026, 8, 1, 0, 15);

      final workDay = AttendanceDay.forShift(instant, HospitalShift.night);

      expect(workDay.value, '2026-07-31');
    });

    test('rechaza una fecha inexistente', () {
      expect(() => AttendanceDay.parse('2026-02-30'), throwsFormatException);
    });
  });
}
