enum HospitalArea {
  emergency,
  hospitalization,
  outpatient,
  surgery,
  pediatrics,
  laboratory,
  pharmacy,
  admission,
  administration,
  cleaning,
  security,
}

extension HospitalAreaDetails on HospitalArea {
  String get value => switch (this) {
    HospitalArea.emergency => 'emergency',
    HospitalArea.hospitalization => 'hospitalization',
    HospitalArea.outpatient => 'outpatient',
    HospitalArea.surgery => 'surgery',
    HospitalArea.pediatrics => 'pediatrics',
    HospitalArea.laboratory => 'laboratory',
    HospitalArea.pharmacy => 'pharmacy',
    HospitalArea.admission => 'admission',
    HospitalArea.administration => 'administration',
    HospitalArea.cleaning => 'cleaning',
    HospitalArea.security => 'security',
  };

  String get label => switch (this) {
    HospitalArea.emergency => 'Emergencia',
    HospitalArea.hospitalization => 'Hospitalización',
    HospitalArea.outpatient => 'Consulta externa',
    HospitalArea.surgery => 'Centro quirúrgico',
    HospitalArea.pediatrics => 'Pediatría',
    HospitalArea.laboratory => 'Laboratorio',
    HospitalArea.pharmacy => 'Farmacia',
    HospitalArea.admission => 'Admisión',
    HospitalArea.administration => 'Administración',
    HospitalArea.cleaning => 'Limpieza',
    HospitalArea.security => 'Seguridad',
  };
}

HospitalArea? hospitalAreaFromValue(Object? value) {
  for (final area in HospitalArea.values) {
    if (area.value == value) return area;
  }
  return null;
}

enum HospitalShift { morning, afternoon, night, guard24h }

extension HospitalShiftDetails on HospitalShift {
  String get value => switch (this) {
    HospitalShift.morning => 'morning',
    HospitalShift.afternoon => 'afternoon',
    HospitalShift.night => 'night',
    HospitalShift.guard24h => 'guard-24h',
  };

  String get label => switch (this) {
    HospitalShift.morning => 'Mañana (07:00–13:00)',
    HospitalShift.afternoon => 'Tarde (13:00–19:00)',
    HospitalShift.night => 'Noche (19:00–07:00)',
    HospitalShift.guard24h => 'Guardia 24 h (07:00–07:00)',
  };

  int get endMinute => switch (this) {
    HospitalShift.morning => 13 * 60,
    HospitalShift.afternoon => 19 * 60,
    HospitalShift.night => 7 * 60,
    HospitalShift.guard24h => 7 * 60,
  };

  bool get spansNextDay {
    return this == HospitalShift.night || this == HospitalShift.guard24h;
  }
}

HospitalShift? hospitalShiftFromValue(Object? value) {
  for (final shift in HospitalShift.values) {
    if (shift.value == value) return shift;
  }
  return null;
}
