import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/entity.dart';
import 'api_provider.dart';

final entitiesProvider = FutureProvider<List<Entity>>((ref) {
  return ref.read(apiClientProvider).listEntities();
});

final entityDetailProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, id) => ref.read(apiClientProvider).getEntityDetail(id),
);
