import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/sync_queue.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }
Future<Task> createOffline(Task task) async {
  return create(task, sync: false);
}

Future<int> updateOffline(Task task) async {
  return update(task, sync: false);
}

Future<int> deleteOffline(int id) async {
  return delete(id, sync: false);
}
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5, // Nova versão para sincronização
      onCreate: _createDB,
      onUpgrade: _migrateDB,
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabela de tasks
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        priority TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        photo_paths TEXT,
        completed_at INTEGER,
        completed_by TEXT,
        latitude REAL,
        longitude REAL,
        location_name TEXT,
        due_date INTEGER,
        server_id TEXT,
        updated_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 1,
        sync_error TEXT,
        last_sync_attempt INTEGER
      )
    ''');

    // Tabela de fila de sincronização
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        last_attempt INTEGER
      )
    ''');

    await _insertSampleTasks(db);
  }

  Future<void> _migrateDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await _addColumnIfNotExists(db, 'tasks', 'photo_path', 'TEXT');
        await _addColumnIfNotExists(db, 'tasks', 'completed_at', 'INTEGER');
        await _addColumnIfNotExists(db, 'tasks', 'completed_by', 'TEXT');
        await _addColumnIfNotExists(db, 'tasks', 'latitude', 'REAL');
        await _addColumnIfNotExists(db, 'tasks', 'longitude', 'REAL');
        await _addColumnIfNotExists(db, 'tasks', 'location_name', 'TEXT');
      } catch (e) {
        print('Erro na migração v1->v2: $e');
      }
    }
    
    if (oldVersion < 3) {
      try {
        await _addColumnIfNotExists(db, 'tasks', 'due_date', 'INTEGER');
      } catch (e) {
        print('Erro na migração v2->v3: $e');
      }
    }
    
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE tasks_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            priority TEXT NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            photo_paths TEXT,
            completed_at INTEGER,
            completed_by TEXT,
            latitude REAL,
            longitude REAL,
            location_name TEXT,
            due_date INTEGER
          )
        ''');
        
        await db.execute('''
          INSERT INTO tasks_new 
          SELECT 
            id, title, description, priority, completed, created_at,
            CASE 
              WHEN photo_path IS NOT NULL AND photo_path != '' THEN photo_path
              ELSE ''
            END as photo_paths,
            completed_at, completed_by, latitude, longitude, location_name, due_date
          FROM tasks
        ''');
        
        await db.execute('DROP TABLE tasks');
        await db.execute('ALTER TABLE tasks_new RENAME TO tasks');
      } catch (e) {
        print('Erro na migração v3->v4: $e');
      }
    }

    if (oldVersion < 5) {
      try {
        // Adicionar novas colunas para sincronização
        await _addColumnIfNotExists(db, 'tasks', 'server_id', 'TEXT');
        await _addColumnIfNotExists(db, 'tasks', 'updated_at', 'INTEGER');
        await _addColumnIfNotExists(db, 'tasks', 'synced', 'INTEGER DEFAULT 1');
        await _addColumnIfNotExists(db, 'tasks', 'sync_error', 'TEXT');
        await _addColumnIfNotExists(db, 'tasks', 'last_sync_attempt', 'INTEGER');

        // Criar tabela de fila de sincronização
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation TEXT NOT NULL,
            table_name TEXT NOT NULL,
            record_id INTEGER NOT NULL,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            last_attempt INTEGER
          )
        ''');

        // Atualizar updated_at para tasks existentes
        await db.execute('''
          UPDATE tasks SET updated_at = created_at WHERE updated_at IS NULL
        ''');

        print('✅ Migração para v5 (sincronização) concluída');
      } catch (e) {
        print('Erro na migração v4->v5: $e');
      }
    }
  }

  Future<void> _addColumnIfNotExists(
    Database db, 
    String table, 
    String column, 
    String type
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final columnExists = columns.any((col) => col['name'] == column);
    
    if (!columnExists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
      print('Coluna $column adicionada à tabela $table');
    } else {
      print('Coluna $column já existe na tabela $table');
    }
  }

  Future<void> _insertSampleTasks(Database db) async {
    final sampleTasks = [
      Task(
        title: 'Bem-vindo ao Task Manager Pro!',
        description: 'Esta é sua primeira tarefa. Toque para editar ou marcar como concluída.',
        priority: 'medium',
        dueDate: DateTime.now().add(const Duration(days: 7)),
        synced: true,
      ),
      Task(
        title: 'Estudar Flutter - Recursos Nativos',
        description: 'Aprender sobre câmera, sensores e GPS',
        priority: 'high',
        dueDate: DateTime.now().add(const Duration(days: 2)),
        synced: true,
      ),
      Task(
        title: 'Testar funcionalidade de Shake',
        description: 'Sacuda o celular para completar tarefas rapidamente!',
        priority: 'urgent',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        synced: true,
      ),
    ];

    for (final task in sampleTasks) {
      await db.insert('tasks', task.toMap());
    }
  }

  // ========== OPERAÇÕES DE TASK ==========

  Future<Task> create(Task task, {bool sync = true}) async {
    final db = await database;
    
    // Se não for para sincronizar, marca como não sincronizado
    final taskToSave = sync ? task : task.copyWith(synced: false);
    
    final id = await db.insert('tasks', taskToSave.toMap());
    final savedTask = taskToSave.copyWith(id: id);

    // Se não for para sincronizar, adiciona à fila
    if (!sync) {
      await _addToSyncQueue('CREATE', 'tasks', id, {});
    }

    return savedTask;
  }

  Future<Task?> read(int id) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> readAll() async {
    final db = await database;
    final orderBy = '''
      CASE 
        WHEN completed = 1 THEN 2
        WHEN due_date IS NULL THEN 1
        ELSE 0
      END,
      due_date ASC,
      created_at DESC
    ''';
    
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> readByStatus(bool completed) async {
    final db = await database;
    final orderBy = completed 
        ? 'completed_at DESC'
        : 'due_date ASC, created_at DESC';
        
    final result = await db.query(
      'tasks',
      where: 'completed = ?',
      whereArgs: [completed ? 1 : 0],
      orderBy: orderBy,
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getPendingSyncTasks() async {
    final db = await database;
    final result = await db.query(
      'tasks',
      where: 'synced = 0',
      orderBy: 'updated_at DESC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> update(Task task, {bool sync = true}) async {
    final db = await database;
    
    // Atualiza o updated_at
    final taskToUpdate = task.copyWith(
      updatedAt: DateTime.now(),
      synced: sync ? task.synced : false,
    );

    final result = await db.update(
      'tasks',
      taskToUpdate.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    // Se não for para sincronizar, adiciona à fila
    if (!sync && result > 0) {
      await _addToSyncQueue('UPDATE', 'tasks', task.id!, {});
    }

    return result;
  }

  Future<int> delete(int id, {bool sync = true}) async {
    final db = await database;
    
    final result = await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );

    // Se não for para sincronizar, adiciona à fila
    if (!sync && result > 0) {
      await _addToSyncQueue('DELETE', 'tasks', id, {});
    }

    return result;
  }

  // ========== FILA DE SINCRONIZAÇÃO ==========

  Future<void> _addToSyncQueue(String operation, String tableName, int recordId, Map<String, dynamic> data) async {
    final db = await database;
    
    final syncItem = SyncQueue(
      operation: operation,
      tableName: tableName,
      recordId: recordId,
      data: data,
    );

    await db.insert('sync_queue', syncItem.toMap());
    print('✅ Item adicionado à fila de sincronização: $operation $tableName:$recordId');
  }

  Future<List<SyncQueue>> getPendingSyncItems() async {
    final db = await database;
    final result = await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
    return result.map((json) => SyncQueue.fromMap(json)).toList();
  }

  Future<void> removeFromSyncQueue(int id) async {
    final db = await database;
    await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSyncQueueItem(SyncQueue item) async {
    final db = await database;
    await db.update(
      'sync_queue',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> markTaskAsSynced(int taskId, String? serverId) async {
    final db = await database;
    await db.update(
      'tasks',
      {
        'synced': 1,
        'server_id': serverId,
        'sync_error': null,
        'last_sync_attempt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> markTaskAsSyncFailed(int taskId, String error) async {
    final db = await database;
    await db.update(
      'tasks',
      {
        'sync_error': error,
        'last_sync_attempt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // ========== MÉTODOS EXISTENTES ==========

  Future<List<Task>> getOverdueTasks() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final result = await db.query(
      'tasks',
      where: 'completed = 0 AND due_date IS NOT NULL AND due_date < ?',
      whereArgs: [now],
      orderBy: 'due_date ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<List<Task>> getDueTodayTasks() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;
    
    final result = await db.query(
      'tasks',
      where: 'completed = 0 AND due_date IS NOT NULL AND due_date BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'due_date ASC',
    );
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<int> getTaskCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM tasks');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getCompletedCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM tasks WHERE completed = 1'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getOverdueCount() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM tasks WHERE completed = 0 AND due_date IS NOT NULL AND due_date < ?',
      [now]
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM tasks WHERE synced = 0'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}