import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../services/database_service.dart';

class ApiService {
  static final ApiService instance = ApiService._init();
  
  static const String baseUrl = 'http://10.0.2.2:3000/api';
  static const Duration timeout = Duration(seconds: 10);

  ApiService._init();

  Future<bool> isApiAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Servidor não disponível: $e');
      return false;
    }
  }

  Future<List<Task>> syncTasks(List<Task> localTasks) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/tasks'))
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<Task> serverTasks = data.map((json) => Task.fromApiMap(json)).toList();

        print('🔄 Sync: ${serverTasks.length} tasks do servidor');

        return _resolveConflicts(localTasks, serverTasks);
      } else {
        throw Exception('Erro no servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro na sincronização: $e');
      rethrow;
    }
  }

  List<Task> _resolveConflicts(List<Task> localTasks, List<Task> serverTasks) {
    final Map<String, Task> mergedTasks = {};

    for (final serverTask in serverTasks) {
      if (serverTask.serverId != null) {
        mergedTasks[serverTask.serverId!] = serverTask;
      }
    }

    for (final localTask in localTasks) {
      if (localTask.serverId != null && mergedTasks.containsKey(localTask.serverId)) {
        final Task serverTask = mergedTasks[localTask.serverId]!;
        
        final localUpdated = localTask.updatedAt ?? localTask.createdAt;
        final serverUpdated = serverTask.updatedAt ?? serverTask.createdAt;
        
        if (localUpdated!.isAfter(serverUpdated!)) {
          mergedTasks[localTask.serverId!] = localTask;
          print('⚖️ LOCAL wins: "${localTask.title}"');
        } else {
          print('⚖️ SERVER wins: "${serverTask.title}"');
        }
      } else if (localTask.serverId == null) {
        final String tempId = 'local_${localTask.id}';
        mergedTasks[tempId] = localTask;
      }
    }

    return mergedTasks.values.toList();
  }
  Future<Task> createTask(Task task) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/tasks'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(task.toApiMap()),
        )
        .timeout(timeout);

    if (response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Task.fromApiMap(data);
    } else {
      throw Exception('Erro ao criar task: ${response.statusCode}');
    }
  }

  Future<Task> updateTask(Task task) async {
    if (task.serverId == null) {
      throw Exception('Task não tem serverId');
    }

    final response = await http
        .put(
          Uri.parse('$baseUrl/tasks/${task.serverId}'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(task.toApiMap()),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Task.fromApiMap(data);
    } else {
      throw Exception('Erro ao atualizar task: ${response.statusCode}');
    }
  }

  Future<void> deleteTask(String serverId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/tasks/$serverId'))
        .timeout(timeout);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Erro ao deletar task: ${response.statusCode}');
    }
  }

  Future<bool> processSyncItem(Map<String, dynamic> item) async {
    try {
      final String operation = item['operation'];
      final int recordId = item['recordId'];

      final task = await DatabaseService.instance.read(recordId);
      if (task == null) return false;

      switch (operation) {
        case 'CREATE':
          final createdTask = await createTask(task);
          await DatabaseService.instance.markTaskAsSynced(task.id!, createdTask.serverId);
          break;
        case 'UPDATE':
          if (task.serverId != null) {
            await updateTask(task);
            await DatabaseService.instance.markTaskAsSynced(task.id!, task.serverId);
          }
          break;
        case 'DELETE':
          if (task.serverId != null) {
            await deleteTask(task.serverId!);
          }
          break;
      }
      
      return true;
    } catch (e) {
      print('❌ Erro ao processar item: $e');
      await DatabaseService.instance.markTaskAsSyncFailed(item['recordId'], e.toString());
      return false;
    }
  }
}