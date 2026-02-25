class Block {
  final String id;
  final String? parentId;
  final String type;
  final String content;
  final double position;
  final int createdAt;
  final int updatedAt;
  final int? archivedAt;

  const Block({
    required this.id,
    this.parentId,
    required this.type,
    required this.content,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  factory Block.fromJson(Map<String, dynamic> json) {
    return Block(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      type: json['type'] as String,
      content: json['content'] as String,
      position: (json['position'] as num).toDouble(),
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
      archivedAt: json['archived_at'] as int?,
    );
  }

  Block copyWith({
    String? content,
    String? type,
  }) {
    return Block(
      id: id,
      parentId: parentId,
      type: type ?? this.type,
      content: content ?? this.content,
      position: position,
      createdAt: createdAt,
      updatedAt: updatedAt,
      archivedAt: archivedAt,
    );
  }
}
