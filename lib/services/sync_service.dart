import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../models/task.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  
  bool _isSyncing = false;
  DateTime? _lastSync;

  SyncService._init();

  bool get isSyncing => _isSyncing;
  DateTime? get lastSync => _lastSync;

  void setupAutoSync() {
    ConnectivityService.instance.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (ConnectivityService.instance.isOnline) {
      Future.delayed(const Duration(seconds: 2), () {
        syncData();
      });
    }
  }

  Future<bool> syncData() async {
    if (_isSyncing) {
      print('⏳ Sincronização já em andamento...');
      return false;
    }

    if (!ConnectivityService.instance.isOnline) {
      print('❌ Sem conexão para sincronizar');
      return false;
    }

    _isSyncing = true;
    print('🔄 Iniciando sincronização...');

    try {
      final pendingTasks = await DatabaseService.instance.getPendingSyncTasks();
      print('📋 ${pendingTasks.length} tasks pendentes de sincronização');

      final allLocalTasks = await DatabaseService.instance.readAll();
      final synchronizedTasks = await ApiService.instance.syncTasks(allLocalTasks);

      print('💾 Salvando ${synchronizedTasks.length} tasks no banco local...');

      for (final syncedTask in synchronizedTasks) {
        try {
          final existingTasks = await DatabaseService.instance.readAll();
          final existingTask = existingTasks.firstWhere(
            (t) => t.serverId == syncedTask.serverId,
            orElse: () => Task(id: -1, title: ''), 
          );

          if (existingTask.id != null && existingTask.id! > 0) {
            final taskToUpdate = syncedTask.copyWith(id: existingTask.id);
            await DatabaseService.instance.update(taskToUpdate);
            print('📝 Task atualizada: "${syncedTask.title}" (local: ${existingTask.id})');
          } else {
            final createdTask = await DatabaseService.instance.create(syncedTask);
            print('🆕 Task criada: "${createdTask.title}" (server: ${syncedTask.serverId})');
          }
        } catch (e) {
          print('❌ Erro ao salvar task "${syncedTask.title}": $e');
        }
      }

      print('🧹 Verificando tasks locais obsoletas...');
      final currentLocalTasks = await DatabaseService.instance.readAll();
      final serverTaskIds = synchronizedTasks.map((t) => t.serverId).where((id) => id != null).toSet();

      for (final localTask in currentLocalTasks) {
        if (localTask.serverId != null && !serverTaskIds.contains(localTask.serverId)) {
          await DatabaseService.instance.delete(localTask.id!);
          print('🗑️ Task removida: "${localTask.title}" (não existe no servidor)');
        }
      }

      final syncQueue = await DatabaseService.instance.getPendingSyncItems();
      print('📨 ${syncQueue.length} itens na fila de sincronização');

      for (final item in syncQueue) {
        try {
          final success = await ApiService.instance.processSyncItem({
            'id': item.id!,
            'operation': item.operation,
            'recordId': item.recordId,
            'data': item.data,
          });

          if (success) {
            await DatabaseService.instance.removeFromSyncQueue(item.id!);
            print('✅ Item ${item.id} sincronizado com sucesso');
          } else {
            final updatedItem = item.copyWith(
              retryCount: item.retryCount + 1,
              lastAttempt: DateTime.now(),
              lastError: 'Falha na sincronização',
            );
            await DatabaseService.instance.updateSyncQueueItem(updatedItem);
          }
        } catch (e) {
          print('❌ Erro ao processar item ${item.id}: $e');
          
          final updatedItem = item.copyWith(
            retryCount: item.retryCount + 1,
            lastAttempt: DateTime.now(),
            lastError: e.toString(),
          );
          await DatabaseService.instance.updateSyncQueueItem(updatedItem);
        }
      }

      _lastSync = DateTime.now();
      print('✅ Sincronização concluída em $_lastSync');
      return true;

    } catch (e) {
      print('❌ Erro na sincronização: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> forceSync() async {
    print('🔄 Forçando sincronização manual...');
    return await syncData();
  }

  Future<SyncStatus> getSyncStatus() async {
    final pendingCount = await DatabaseService.instance.getPendingSyncCount();
    final queueItems = await DatabaseService.instance.getPendingSyncItems();
    
    return SyncStatus(
      pendingTasks: pendingCount,
      pendingQueueItems: queueItems.length,
      lastSync: _lastSync,
      isOnline: ConnectivityService.instance.isOnline,
      isSyncing: _isSyncing,
    );
  }

  Future<void> dispose() {
    ConnectivityService.instance.removeListener(_onConnectivityChanged);
    return Future.value();
  }
}

class SyncStatus {
  final int pendingTasks;
  final int pendingQueueItems;
  final DateTime? lastSync;
  final bool isOnline;
  final bool isSyncing;

  SyncStatus({
    required this.pendingTasks,
    required this.pendingQueueItems,
    required this.lastSync,
    required this.isOnline,
    required this.isSyncing,
  });

  bool get hasPendingChanges => pendingTasks > 0 || pendingQueueItems > 0;
  bool get canSync => isOnline && !isSyncing && hasPendingChanges;
}