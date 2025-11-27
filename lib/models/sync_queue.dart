class SyncQueue {
  final int? id;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final String tableName;
  final int recordId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final DateTime? lastAttempt;

  SyncQueue({
    this.id,
    required this.operation,
    required this.tableName,
    required this.recordId,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
    this.lastError,
    this.lastAttempt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operation': operation,
      'table_name': tableName,
      'record_id': recordId,
      'data': _encodeData(data),
      'created_at': createdAt.millisecondsSinceEpoch,
      'retry_count': retryCount,
      'last_error': lastError,
      'last_attempt': lastAttempt?.millisecondsSinceEpoch,
    };
  }

  factory SyncQueue.fromMap(Map<String, dynamic> map) {
    return SyncQueue(
      id: map['id'],
      operation: map['operation'],
      tableName: map['table_name'],
      recordId: map['record_id'],
      data: _decodeData(map['data']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      retryCount: map['retry_count'],
      lastError: map['last_error'],
      lastAttempt: map['last_attempt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['last_attempt'])
          : null,
    );
  }

  static String _encodeData(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}::${e.value}').join('|||');
  }

  static Map<String, dynamic> _decodeData(String data) {
    final Map<String, dynamic> result = {};
    final entries = data.split('|||');
    for (final entry in entries) {
      final parts = entry.split('::');
      if (parts.length == 2) {
        result[parts[0]] = parts[1];
      }
    }
    return result;
  }

  SyncQueue copyWith({
    int? id,
    String? operation,
    String? tableName,
    int? recordId,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    int? retryCount,
    String? lastError,
    DateTime? lastAttempt,
  }) {
    return SyncQueue(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      lastAttempt: lastAttempt ?? this.lastAttempt,
    );
  }
}