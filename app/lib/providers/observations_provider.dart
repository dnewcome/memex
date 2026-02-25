import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/observation.dart';
import 'api_provider.dart';

// In-memory store of pending observations per block
final pendingObservationsProvider =
    StateProvider<Map<String, List<PendingObservation>>>((ref) => {});

extension PendingObservationsNotifier on StateController<Map<String, List<PendingObservation>>> {
  void setForBlock(String blockId, List<PendingObservation> observations) {
    state = {...state, blockId: observations};
  }

  void removeObservation(String blockId, String observationId) {
    final updated = (state[blockId] ?? [])
        .where((o) => o.observation.id != observationId)
        .toList();
    state = {...state, blockId: updated};
  }
}

// Confirm an observation and remove it from pending
Future<void> confirmObservation(
  WidgetRef ref,
  String blockId,
  String observationId,
) async {
  await ref.read(apiClientProvider).confirmObservation(observationId);
  ref.read(pendingObservationsProvider.notifier).removeObservation(blockId, observationId);
}

// Dismiss an observation and remove it from pending
Future<void> dismissObservation(
  WidgetRef ref,
  String blockId,
  String observationId,
) async {
  await ref.read(apiClientProvider).dismissObservation(observationId);
  ref.read(pendingObservationsProvider.notifier).removeObservation(blockId, observationId);
}
