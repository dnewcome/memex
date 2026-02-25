import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/block.dart';
import 'api_provider.dart';

// ─── Root blocks list ─────────────────────────────────────────────────────

class BlocksNotifier extends AsyncNotifier<List<Block>> {
  @override
  Future<List<Block>> build() async {
    return ref.read(apiClientProvider).listBlocks();
  }

  Future<Block> createBlock({String content = '', String type = 'text'}) async {
    final api = ref.read(apiClientProvider);
    final block = await api.createBlock(content: content, type: type);
    state = AsyncData([...state.valueOrNull ?? [], block]);
    return block;
  }

  Future<void> deleteBlock(String id) async {
    await ref.read(apiClientProvider).deleteBlock(id);
    state = AsyncData(
      (state.valueOrNull ?? []).where((b) => b.id != id).toList(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(apiClientProvider).listBlocks());
  }
}

final blocksProvider = AsyncNotifierProvider<BlocksNotifier, List<Block>>(
  BlocksNotifier.new,
);

// ─── Single block detail ──────────────────────────────────────────────────

final blockDetailProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, id) => ref.read(apiClientProvider).getBlockDetail(id),
);
