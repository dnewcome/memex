import 'entity.dart';

class Observation {
  final String id;
  final String entityId;
  final String blockId;
  final int observedAt;
  final String status;
  final String source;
  final int createdAt;

  const Observation({
    required this.id,
    required this.entityId,
    required this.blockId,
    required this.observedAt,
    required this.status,
    required this.source,
    required this.createdAt,
  });

  factory Observation.fromJson(Map<String, dynamic> json) {
    return Observation(
      id: json['id'] as String,
      entityId: json['entity_id'] as String,
      blockId: json['block_id'] as String,
      observedAt: json['observed_at'] as int,
      status: json['status'] as String,
      source: json['source'] as String,
      createdAt: json['created_at'] as int,
    );
  }
}

class PendingObservation {
  final Observation observation;
  final Entity entity;
  final int priorCount;
  final int? lastObservedAt;

  const PendingObservation({
    required this.observation,
    required this.entity,
    required this.priorCount,
    this.lastObservedAt,
  });

  factory PendingObservation.fromJson(Map<String, dynamic> json) {
    return PendingObservation(
      observation: Observation.fromJson(json['observation'] as Map<String, dynamic>),
      entity: Entity.fromJson(json['entity'] as Map<String, dynamic>),
      priorCount: json['prior_count'] as int,
      lastObservedAt: json['last_observed_at'] as int?,
    );
  }

  /// Human-readable "have you seen this before?" string.
  String get contextMessage {
    if (priorCount == 0) {
      return 'First time referencing ${entity.name}';
    }
    final times = priorCount == 1 ? '1 time' : '$priorCount times';
    if (lastObservedAt == null) {
      return "You've referenced ${entity.name} $times before";
    }
    final daysAgo = _daysAgo(lastObservedAt!);
    if (daysAgo == 0) {
      return "You've referenced ${entity.name} $times, last today";
    }
    final dayStr = daysAgo == 1 ? '1 day ago' : '$daysAgo days ago';
    return "You've referenced ${entity.name} $times, last $dayStr";
  }

  int _daysAgo(int timestampMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ((now - timestampMs) / (1000 * 60 * 60 * 24)).floor();
  }
}
