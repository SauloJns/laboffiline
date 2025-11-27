class Task {
  final int? id;
  final String title;
  final String description;
  final bool completed;
  final String priority;
  final DateTime createdAt;
  
  final List<String> photoPaths;
  final DateTime? completedAt;
  final String? completedBy;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final DateTime? dueDate;

  // Novos campos para sincronização
  final String? serverId;
  final DateTime? updatedAt;
  final bool synced;
  final String? syncError;
  final DateTime? lastSyncAttempt;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.priority = 'medium',
    DateTime? createdAt,
    List<String>? photoPaths,
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
    this.dueDate,
    this.serverId,
    DateTime? updatedAt,
    this.synced = true,
    this.syncError,
    this.lastSyncAttempt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now(),
       photoPaths = photoPaths ?? [];

  bool get hasPhotos => photoPaths.isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;
  bool get wasCompletedByShake => completedBy == 'shake';
  bool get isOverdue => !completed && dueDate != null && dueDate!.isBefore(DateTime.now());
  bool get isDueToday => !completed && dueDate != null && 
      dueDate!.year == DateTime.now().year &&
      dueDate!.month == DateTime.now().month &&
      dueDate!.day == DateTime.now().day;
  bool get isDueSoon => !completed && dueDate != null && 
      dueDate!.isAfter(DateTime.now()) &&
      dueDate!.difference(DateTime.now()).inDays <= 3;
  
  // Novo getter para status de sincronização
  bool get isPendingSync => !synced;
  bool get hasSyncError => syncError != null && syncError!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'priority': priority,
      'created_at': createdAt.millisecondsSinceEpoch,
      'photo_paths': photoPaths.join('|||'),
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'completed_by': completedBy,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'due_date': dueDate?.millisecondsSinceEpoch,
      // Novos campos
      'server_id': serverId,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'synced': synced ? 1 : 0,
      'sync_error': syncError,
      'last_sync_attempt': lastSyncAttempt?.millisecondsSinceEpoch,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      completed: map['completed'] == 1,
      priority: map['priority'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      photoPaths: map['photo_paths'] != null
          ? (map['photo_paths'] as String).split('|||')
          : [],
      completedAt: map['completed_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'])
          : null,
      completedBy: map['completed_by'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      locationName: map['location_name'],
      dueDate: map['due_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['due_date'])
          : null,
      // Novos campos
      serverId: map['server_id'],
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
      synced: map['synced'] == 1,
      syncError: map['sync_error'],
      lastSyncAttempt: map['last_sync_attempt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_sync_attempt'])
          : null,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    bool? completed,
    String? priority,
    DateTime? createdAt,
    List<String>? photoPaths,
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
    DateTime? dueDate,
    String? serverId,
    DateTime? updatedAt,
    bool? synced,
    String? syncError,
    DateTime? lastSyncAttempt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      photoPaths: photoPaths ?? this.photoPaths,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      dueDate: dueDate ?? this.dueDate,
      serverId: serverId ?? this.serverId,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      syncError: syncError ?? this.syncError,
      lastSyncAttempt: lastSyncAttempt ?? this.lastSyncAttempt,
    );
  }

  // Para API
  Map<String, dynamic> toApiMap() {
    return {
      'id': serverId,
      'title': title,
      'description': description,
      'completed': completed,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'completed_by': completedBy,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'due_date': dueDate?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'local_id': id, // Para identificar no servidor
    };
  }

  factory Task.fromApiMap(Map<String, dynamic> map) {
    return Task(
      serverId: map['id']?.toString(),
      title: map['title'],
      description: map['description'] ?? '',
      completed: map['completed'] ?? false,
      priority: map['priority'] ?? 'medium',
      createdAt: DateTime.parse(map['created_at']),
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
      completedBy: map['completed_by'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      locationName: map['location_name'],
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      synced: true, // Vindo do servidor = sincronizado
    );
  }

  String get shareText {
    final buffer = StringBuffer();
    
    buffer.writeln('📋 $title');
    buffer.writeln();
    
    if (description.isNotEmpty) {
      buffer.writeln('📝 $description');
      buffer.writeln();
    }
    
    buffer.writeln('📊 Status: ${completed ? '✅ Concluída' : '⏳ Pendente'}');
    buffer.writeln('🎯 Prioridade: ${_getPriorityLabel()}');
    
    if (dueDate != null) {
      final now = DateTime.now();
      final difference = dueDate!.difference(now);
      
      String status;
      if (completed) {
        status = '✅ Concluída';
      } else if (dueDate!.isBefore(now)) {
        status = '🔴 Vencida';
      } else if (difference.inDays == 0) {
        status = '🟡 Vence hoje';
      } else if (difference.inDays <= 3) {
        status = '🟠 Vence em ${difference.inDays} dias';
      } else {
        status = '🟢 Vence em ${difference.inDays} dias';
      }
      
      buffer.writeln('📅 Vencimento: ${_formatDate(dueDate!)} ($status)');
    }
    
    if (hasLocation && locationName != null) {
      buffer.writeln('📍 Local: $locationName');
    }
    
    if (hasPhotos) {
      buffer.writeln('📸 Fotos: ${photoPaths.length} anexada(s)');
    }
    
    if (completed && completedAt != null) {
      buffer.writeln('✅ Concluída em: ${_formatDate(completedAt!)}');
    }

    // Status de sincronização
    if (!synced) {
      buffer.writeln('🔄 Status: Aguardando sincronização');
    } else if (hasSyncError) {
      buffer.writeln('❌ Erro de sincronização: $syncError');
    }
    
    buffer.writeln();
    buffer.writeln('Criado com Task Manager Pro 📱');
    
    return buffer.toString();
  }

  String _getPriorityLabel() {
    switch (priority) {
      case 'urgent': return '🔴 Urgente';
      case 'high': return '🟠 Alta';
      case 'medium': return '🟡 Média';
      case 'low': return '🟢 Baixa';
      default: return 'Normal';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, completed: $completed, synced: $synced, serverId: $serverId)';
  }
}