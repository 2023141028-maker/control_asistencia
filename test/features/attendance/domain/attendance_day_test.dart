import 'package:control_asistencia/features/attendance/domain/attendance_day.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('rechaza una fecha inexistente', () {
      expect(() => AttendanceDay.parse('2026-02-30'), throwsFormatException);
    });
  });
}
