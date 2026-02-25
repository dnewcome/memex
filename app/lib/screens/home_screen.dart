import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/block.dart';
import '../providers/blocks_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(blocksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memex'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_tree_outlined),
            tooltip: 'Entities',
            onPressed: () => context.push('/entities'),
          ),
        ],
      ),
      body: blocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $e'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.read(blocksProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (blocks) => _BlockList(blocks: blocks),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createBlock(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }

  Future<void> _createBlock(BuildContext context, WidgetRef ref) async {
    final block = await ref.read(blocksProvider.notifier).createBlock();
    if (context.mounted) {
      context.push('/blocks/${block.id}');
    }
  }
}

class _BlockList extends ConsumerWidget {
  final List<Block> blocks;

  const _BlockList({required this.blocks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (blocks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_add_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No notes yet.\nTap + to create your first note.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(blocksProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: blocks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (context, i) => _BlockTile(block: blocks[i]),
      ),
    );
  }
}

class _BlockTile extends ConsumerWidget {
  final Block block;

  const _BlockTile({required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = block.content.isEmpty ? '(empty)' : block.content;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(block.updatedAt);
    final ago = _timeAgo(timestamp);

    return Card(
      child: ListTile(
        title: Text(
          preview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(ago, style: const TextStyle(fontSize: 12)),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete note?'),
                  content: const Text('This will archive the note.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete')),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(blocksProvider.notifier).deleteBlock(block.id);
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => context.push('/blocks/${block.id}'),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
