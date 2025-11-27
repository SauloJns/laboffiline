import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../services/database_service.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  
  // URL base da API - altere para sua API real
  static const String baseUrl = 'https://your-api.com/api';
  static const Duration timeout = Duration(seconds: 10);

  ApiService._init();

  // Simulação de API para demonstração
  bool _simulateOffline = false;
  bool _simulateError = false;

  void setSimulateOffline(bool offline) {
    _simulateOffline = offline;
  }

  void setSimulateError(bool error) {
    _simulateError = error;
  }

  // Verificar se a API está disponível
  Future<bool> isApiAvailable() async {
    if (_simulateOffline) return false;
    
    // SEMPRE RETORNA TRUE PARA DEMONSTRAÇÃO
    return true;
  }

  // Sincronizar todas as tarefas - VERSÃO SIMULADA
  Future<List<Task>> syncTasks(List<Task> localTasks) async {
    if (_simulateOffline) {
      throw Exception('Simulação: API offline');
    }

    if (_simulateError) {
      throw Exception('Simulação: Erro de servidor');
    }

    print('🔄 Simulando sync de ${localTasks.length} tasks');
    
    // SIMULA PROCESSAMENTO
    await Future.delayed(const Duration(seconds: 2));
    
    // Marca todas as tasks pendentes como sincronizadas
    final db = await DatabaseService.instance.database;
    for (final task in localTasks.where((t) => !t.synced)) {
      await db.update(
        'tasks',
        {
          'synced': 1,
          'server_id': 'server_${task.id}_${DateTime.now().millisecondsSinceEpoch}',
          'sync_error': null,
          'last_sync_attempt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [task.id],
      );
    }

    print('✅ Sync simulado concluído! Todas as tasks marcadas como sincronizadas.');
    
    // Retorna as tasks atualizadas
    final updatedTasks = await DatabaseService.instance.readAll();
    return updatedTasks;
  }

  // Resolver conflitos LWW - VERSÃO SIMULADA
  List<Task> _resolveConflicts(List<Task> localTasks, List<Task> serverTasks) {
    final Map<String, Task> mergedTasks = {};

    // Adicionar tasks do servidor
    for (final serverTask in serverTasks) {
      if (serverTask.serverId != null) {
        mergedTasks[serverTask.serverId!] = serverTask;
      }
    }

    // Mesclar com tasks locais (LWW)
    for (final localTask in localTasks) {
      if (localTask.serverId != null && mergedTasks.containsKey(localTask.serverId)) {
        // Conflito: verificar qual é mais recente
        final Task serverTask = mergedTasks[localTask.serverId]!;
        
        if (localTask.updatedAt!.isAfter(serverTask.updatedAt!)) {
          // Local é mais recente - sobrescrever
          mergedTasks[localTask.serverId!] = localTask;
          print('⚖️ Conflito resolvido: LOCAL wins (mais recente)');
        } else {
          // Server wins - mantém a do servidor
          print('⚖️ Conflito resolvido: SERVER wins (mais recente)');
        }
      } else if (localTask.serverId == null) {
        // Task local nova - adicionar com ID temporário
        final String tempId = 'local_${localTask.id}';
        mergedTasks[tempId] = localTask;
      }
    }

    return mergedTasks.values.toList();
  }

  // Criar task no servidor - VERSÃO SIMULADA
  Future<Task> createTask(Task task) async {
    if (_simulateOffline) throw Exception('Simulação: API offline');
    if (_simulateError) throw Exception('Simulação: Erro de servidor');

    print('🔄 Simulando criação da task: "${task.title}"');
    
    // SIMULA CRIAÇÃO NO SERVIDOR
    await Future.delayed(const Duration(seconds: 1));
    
    // Retorna task com serverId simulado
    return task.copyWith(
      serverId: 'server_${task.id}_${DateTime.now().millisecondsSinceEpoch}',
      synced: true,
    );
  }

  // Atualizar task no servidor - VERSÃO SIMULADA
  Future<Task> updateTask(Task task) async {
    if (_simulateOffline) throw Exception('Simulação: API offline');
    if (_simulateError) throw Exception('Simulação: Erro de servidor');

    print('🔄 Simulando atualização da task: "${task.title}"');
    
    // SIMULA ATUALIZAÇÃO NO SERVIDOR
    await Future.delayed(const Duration(seconds: 1));
    
    return task.copyWith(synced: true);
  }

  // Deletar task no servidor - VERSÃO SIMULADA
  Future<void> deleteTask(String serverId) async {
    if (_simulateOffline) throw Exception('Simulação: API offline');
    if (_simulateError) throw Exception('Simulação: Erro de servidor');

    print('🔄 Simulando exclusão da task: $serverId');
    
    // SIMULA EXCLUSÃO NO SERVIDOR
    await Future.delayed(const Duration(seconds: 1));
    
    print('✅ Task $serverId excluída com sucesso (simulado)');
  }

  // Processar item da fila de sincronização - VERSÃO SIMULADA
  Future<bool> processSyncItem(Map<String, dynamic> item) async {
    try {
      final String operation = item['operation'];
      final int recordId = item['recordId'];

      print('🔄 Processando item da fila: $operation task $recordId');
      
      // SIMULA PROCESSAMENTO
      await Future.delayed(const Duration(seconds: 1));

      final db = await DatabaseService.instance.database;
      
      switch (operation) {
        case 'CREATE':
          // Marca como sincronizada
          await db.update(
            'tasks',
            {
              'synced': 1,
              'server_id': 'server_${recordId}_${DateTime.now().millisecondsSinceEpoch}',
              'sync_error': null,
            },
            where: 'id = ?',
            whereArgs: [recordId],
          );
          print('✅ Task $recordId criada no servidor (simulado)');
          break;
        
        case 'UPDATE':
          // Marca como sincronizada
          await db.update(
            'tasks',
            {
              'synced': 1,
              'sync_error': null,
            },
            where: 'id = ?',
            whereArgs: [recordId],
          );
          print('✅ Task $recordId atualizada no servidor (simulado)');
          break;
        
        case 'DELETE':
          // Apenas marca como processada (em um caso real, deletaria do servidor)
          print('✅ Task $recordId marcada para exclusão (simulado)');
          break;
      }
      
      return true;
      
    } catch (e) {
      print('❌ Erro ao processar item da fila: $e');
      
      // Marca como erro de sync
      final db = await DatabaseService.instance.database;
      await db.update(
        'tasks',
        {
          'sync_error': e.toString(),
          'last_sync_attempt': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [item['recordId']],
      );
      
      return false;
    }
  }

  // Método auxiliar para simular resposta do servidor
  Future<Map<String, dynamic>> _simulateServerResponse() async {
    await Future.delayed(const Duration(seconds: 1));
    return {
      'success': true,
      'message': 'Operação simulada com sucesso',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}