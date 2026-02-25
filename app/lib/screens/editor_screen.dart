import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/block.dart';
import '../models/observation.dart';
import '../providers/api_provider.dart';
import '../providers/blocks_provider.dart';
import '../providers/observations_provider.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final String blockId;

  const EditorScreen({super.key, required this.blockId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late TextEditingController _controller;
  Block? _block;
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadBlock();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadBlock() async {
    try {
      final detail = await ref.read(apiClientProvider).getBlockDetail(widget.blockId);
      final block = Block.fromJson(detail['block'] as Map<String, dynamic>);
      setState(() {
        _block = block;
        _controller.text = block.content;
        _loading = false;
      });
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () => _save(value));
  }

  Future<void> _save(String content) async {
    if (_block == null) return;
    try {
      final result = await ref.read(apiClientProvider).patchBlock(
            _block!.id,
            content: content,
          );
      setState(() => _block = result.block);

      // Merge pending observations into state provider
      if (result.pendingObservations.isNotEmpty) {
        ref.read(pendingObservationsProvider.notifier).setForBlock(
              widget.blockId,
              result.pendingObservations,
            );
      }

      // Refresh blocks list in background
      ref.invalidate(blocksProvider);
    } catch (_) {
      // silent fail — will retry on next keystroke
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingMap = ref.watch(pendingObservationsProvider);
    final pending = pendingMap[widget.blockId] ?? [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _debounce?.cancel();
            if (_controller.text != (_block?.content ?? '')) {
              _save(_controller.text);
            }
            context.pop();
          },
        ),
        title: const Text('Note'),
        actions: [
          if (_block != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome_outlined),
              tooltip: 'Entities in this note',
              onPressed: () => _showEntitiesBottomSheet(context),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (pending.isNotEmpty)
                  _PendingObservationsBanner(
                    blockId: widget.blockId,
                    observations: pending,
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _controller,
                      onChanged: _onTextChanged,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            height: 1.6,
                          ),
                      decoration: const InputDecoration(
                        hintText: 'Start writing…\n\nUse [[concept]], @person, #tag, or paste URLs to track connections.',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showEntitiesBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _EntityHintsSheet(blockId: widget.blockId),
    );
  }
}

// ─── Pending observations banner ──────────────────────────────────────────

class _PendingObservationsBanner extends ConsumerWidget {
  final String blockId;
  final List<PendingObservation> observations;

  const _PendingObservationsBanner({
    required this.blockId,
    required this.observations,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Connections found',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          ...observations.map(
            (o) => _ObservationTile(blockId: blockId, pending: o),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ObservationTile extends ConsumerWidget {
  final String blockId;
  final PendingObservation pending;

  const _ObservationTile({required this.blockId, required this.pending});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _entityIcon(pending.entity.type),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pending.contextMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => confirmObservation(ref, blockId, pending.observation.id),
                child: const Text('Add'),
              ),
              TextButton(
                onPressed: () => dismissObservation(ref, blockId, pending.observation.id),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entityIcon(String type) {
    final icon = switch (type) {
      'url' => Icons.link,
      'person' => Icons.person_outline,
      'concept' => Icons.lightbulb_outline,
      'tag' => Icons.tag,
      'place' => Icons.place_outlined,
      'product' => Icons.inventory_2_outlined,
      _ => Icons.label_outline,
    };
    return Icon(icon, size: 18, color: Colors.grey);
  }
}

// ─── Entity hints bottom sheet ────────────────────────────────────────────

class _EntityHintsSheet extends ConsumerWidget {
  final String blockId;

  const _EntityHintsSheet({required this.blockId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingMap = ref.watch(pendingObservationsProvider);
    final pending = pendingMap[blockId] ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      maxChildSize: 0.8,
      expand: false,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Entities in this note',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const Text('No pending connections. Start typing to extract entities.',
                style: TextStyle(color: Colors.grey)),
          ...pending.map(
            (o) => ListTile(
              leading: const Icon(Icons.link),
              title: Text(o.entity.name),
              subtitle: Text(o.contextMessage),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/entities/${o.entity.id}');
              },
            ),
          ),
        ],
      ),
    );
  }
}
