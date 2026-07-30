final class AttendanceDay {
  const AttendanceDay._(this.value);

  static const Duration _limaUtcOffset = Duration(hours: 5);

  static final RegExp _pattern = RegExp(r'^([0-9]{4})-([0-9]{2})-([0-9]{2})$');

  final String value;

  factory AttendanceDay.fromInstant(DateTime instant) {
    final limaDateTime = instant.toUtc().subtract(_limaUtcOffset);

    return AttendanceDay._(
      _format(
        year: limaDateTime.year,
        month: limaDateTime.month,
        day: limaDateTime.day,
      ),
    );
  }

  factory AttendanceDay.parse(String value) {
    final match = _pattern.firstMatch(value);

    if (match == null) {
      throw const FormatException(
        'La fecha laboral debe tener el formato YYYY-MM-DD.',
      );
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);

    final parsedDate = DateTime.utc(year, month, day);

    final validDate =
        year >= 2000 &&
        year <= 2100 &&
        parsedDate.year == year &&
        parsedDate.month == month &&
        parsedDate.day == day;

    if (!validDate) {
      throw const FormatException('La fecha laboral no es válida.');
    }

    return AttendanceDay._(_format(year: year, month: month, day: day));
  }

  String documentIdFor(String userId) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty || normalizedUserId.contains('/')) {
      throw ArgumentError.value(
        userId,
        'userId',
        'El UID no es válido para crear el documento.',
      );
    }

    return '${normalizedUserId}_$value';
  }

  static String _format({
    required int year,
    required int month,
    required int day,
  }) {
    final formattedMonth = month.toString().padLeft(2, '0');
    final formattedDay = day.toString().padLeft(2, '0');

    return '$year-$formattedMonth-$formattedDay';
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) {
    return other is AttendanceDay && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}
