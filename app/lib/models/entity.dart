class Entity {
  final String id;
  final String type;
  final String name;
  final String canonical;
  final String meta;
  final int createdAt;
  final int firstSeenAt;
  final int? observationCount;
  final int? lastObservedAt;

  const Entity({
    required this.id,
    required this.type,
    required this.name,
    required this.canonical,
    required this.meta,
    required this.createdAt,
    required this.firstSeenAt,
    this.observationCount,
    this.lastObservedAt,
  });

  factory Entity.fromJson(Map<String, dynamic> json) {
    return Entity(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      canonical: json['canonical'] as String,
      meta: json['meta'] as String? ?? '{}',
      createdAt: json['created_at'] as int,
      firstSeenAt: json['first_seen_at'] as int,
      observationCount: json['observation_count'] as int?,
      lastObservedAt: json['last_observed_at'] as int?,
    );
  }
}
