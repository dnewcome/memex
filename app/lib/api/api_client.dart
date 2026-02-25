import 'package:dio/dio.dart';
import '../models/block.dart';
import '../models/entity.dart';
import '../models/observation.dart';

class ApiClient {
  static const String _baseUrl = 'http://localhost:3000/api/v1';

  final Dio _dio;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  // ─── Blocks ──────────────────────────────────────────────────────────────

  Future<List<Block>> listBlocks() async {
    final res = await _dio.get('/blocks');
    final data = res.data['data'] as List;
    return data.map((j) => Block.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Block> createBlock({
    String? parentId,
    String type = 'text',
    String content = '',
    double? position,
  }) async {
    final res = await _dio.post('/blocks', data: {
      if (parentId != null) 'parent_id': parentId,
      'type': type,
      'content': content,
      if (position != null) 'position': position,
    });
    return Block.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getBlockDetail(String id) async {
    final res = await _dio.get('/blocks/$id');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<({Block block, List<PendingObservation> pendingObservations})> patchBlock(
    String id, {
    String? content,
    String? type,
  }) async {
    final res = await _dio.patch('/blocks/$id', data: {
      if (content != null) 'content': content,
      if (type != null) 'type': type,
    });
    final block = Block.fromJson(res.data['data'] as Map<String, dynamic>);
    final pending = (res.data['pending_observations'] as List)
        .map((j) => PendingObservation.fromJson(j as Map<String, dynamic>))
        .toList();
    return (block: block, pendingObservations: pending);
  }

  Future<void> deleteBlock(String id) async {
    await _dio.delete('/blocks/$id');
  }

  // ─── Entities ────────────────────────────────────────────────────────────

  Future<List<Entity>> listEntities() async {
    final res = await _dio.get('/entities');
    final data = res.data['data'] as List;
    return data.map((j) => Entity.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Entity>> searchEntities(String q) async {
    final res = await _dio.get('/entities/search', queryParameters: {'q': q});
    final data = res.data['data'] as List;
    return data.map((j) => Entity.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getEntityDetail(String id) async {
    final res = await _dio.get('/entities/$id');
    return res.data['data'] as Map<String, dynamic>;
  }

  // ─── Observations ────────────────────────────────────────────────────────

  Future<Observation> confirmObservation(String id) async {
    final res = await _dio.patch('/observations/$id', data: {'status': 'confirmed'});
    return Observation.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<Observation> dismissObservation(String id) async {
    final res = await _dio.patch('/observations/$id', data: {'status': 'dismissed'});
    return Observation.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
