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

  // Sincronização automática quando a conexão retorna
  void setupAutoSync() {
    ConnectivityService.instance.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (ConnectivityService.instance.isOnline) {
      // Esperar um pouco para garantir que a conexão está estável
      Future.delayed(const Duration(seconds: 2), () {
        syncData();
      });
    }
  }

  // Sincronizar todos os dados
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
      // 1. Buscar tasks pendentes de sincronização
      final pendingTasks = await DatabaseService.instance.getPendingSyncTasks();
      print('📋 ${pendingTasks.length} tasks pendentes de sincronização');

      // 2. Buscar tasks do servidor e resolver conflitos
      final allLocalTasks = await DatabaseService.instance.readAll();
      final synchronizedTasks = await ApiService.instance.syncTasks(allLocalTasks);

      // 3. Atualizar tasks locais com dados do servidor
      for (final syncedTask in synchronizedTasks) {
        // Encontrar task local correspondente
        final localTask = allLocalTasks.firstWhere(
          (t) => t.serverId == syncedTask.serverId || t.id == syncedTask.id,
          orElse: () => syncedTask,
        );

        // Atualizar apenas se necessário
        if (localTask.updatedAt == null || 
            syncedTask.updatedAt!.isAfter(localTask.updatedAt!)) {
          await DatabaseService.instance.update(syncedTask);
        }
      }

      // 4. Processar fila de sincronização
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
            // Incrementar contador de tentativas
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
      print('✅ Sincronização concluída em ${_lastSync}');
      return true;

    } catch (e) {
      print('❌ Erro na sincronização: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // Forçar sincronização manual
  Future<bool> forceSync() async {
    print('🔄 Forçando sincronização manual...');
    return await syncData();
  }

  // Verificar status da sincronização
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