import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/entity.dart';
import '../providers/entities_provider.dart';

// ─── Entity list screen ────────────────────────────────────────────────────

class EntityListScreen extends ConsumerWidget {
  const EntityListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitiesAsync = ref.watch(entitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Entities')),
      body: entitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entities) {
          if (entities.isEmpty) {
            return const Center(
              child: Text('No entities yet.\nWrite notes with [[concepts]], @people, #tags, or URLs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (ctx, i) => _EntityTile(entity: entities[i]),
          );
        },
      ),
    );
  }
}

class _EntityTile extends StatelessWidget {
  final Entity entity;

  const _EntityTile({required this.entity});

  @override
  Widget build(BuildContext context) {
    final count = entity.observationCount ?? 0;
    final lastSeen = entity.lastObservedAt != null
        ? _timeAgo(DateTime.fromMillisecondsSinceEpoch(entity.lastObservedAt!))
        : null;

    return Card(
      child: ListTile(
        leading: _entityIcon(entity.type),
        title: Text(entity.name),
        subtitle: Text(
          count == 0
              ? 'No confirmed references'
              : lastSeen != null
                  ? '$count reference${count == 1 ? '' : 's'} · last $lastSeen'
                  : '$count reference${count == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => context.push('/entities/${entity.id}'),
      ),
    );
  }

  Widget _entityIcon(String type) {
    final data = switch (type) {
      'url' => (Icons.link, Colors.blue),
      'person' => (Icons.person_outline, Colors.green),
      'concept' => (Icons.lightbulb_outline, Colors.amber),
      'tag' => (Icons.tag, Colors.purple),
      'place' => (Icons.place_outlined, Colors.red),
      'product' => (Icons.inventory_2_outlined, Colors.orange),
      _ => (Icons.label_outline, Colors.grey),
    };
    return CircleAvatar(
      backgroundColor: data.$2.withOpacity(0.15),
      child: Icon(data.$1, color: data.$2, size: 18),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ─── Entity detail screen ──────────────────────────────────────────────────

class EntityDetailScreen extends ConsumerWidget {
  final String entityId;

  const EntityDetailScreen({super.key, required this.entityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(entityDetailProvider(entityId));

    return Scaffold(
      appBar: AppBar(title: const Text('Entity')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          final entity = Entity.fromJson(data['entity'] as Map<String, dynamic>);
          final timeline = data['timeline'] as List;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _typeChip(entity.type),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entity.name,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entity.canonical,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontFamily: 'monospace',
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Observation timeline',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (timeline.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No confirmed observations yet.',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final item = timeline[i] as Map<String, dynamic>;
                      final obs = item['observation'] as Map<String, dynamic>;
                      final block = item['block'] as Map<String, dynamic>;
                      final dt = DateTime.fromMillisecondsSinceEpoch(
                          obs['observed_at'] as int);
                      final content = block['content'] as String;
                      final preview = content.length > 120
                          ? '${content.substring(0, 120)}…'
                          : content;

                      return ListTile(
                        leading: const Icon(Icons.history, size: 18),
                        title: Text(
                          preview.isEmpty ? '(empty block)' : preview,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} · ${obs['status']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => context.push('/blocks/${block['id']}'),
                      );
                    },
                    childCount: timeline.length,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _typeChip(String type) {
    return Chip(
      label: Text(type, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
