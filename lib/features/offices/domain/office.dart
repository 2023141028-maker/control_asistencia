class Office {
  const Office({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.maxAccuracyMeters,
    required this.timezone,
    required this.active,
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final double maxAccuracyMeters;
  final String timezone;
  final bool active;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
}
