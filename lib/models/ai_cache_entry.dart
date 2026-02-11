class AiCacheEntry {
  final int? id;
  final String cacheKey;
  final String response;
  final DateTime createdAt;

  AiCacheEntry({
    this.id,
    required this.cacheKey,
    required this.response,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cache_key': cacheKey,
      'response': response,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AiCacheEntry.fromMap(Map<String, dynamic> map) {
    return AiCacheEntry(
      id: map['id'] as int?,
      cacheKey: map['cache_key'] as String,
      response: map['response'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
