import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../screens/task_form_screen.dart';
import '../widgets/task_card.dart';
import '../widgets/connectivity_status.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  String _filter = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _checkOverdueTasks();
    _setupConnectivityListener();
    _setupAutoSync();
  }

  @override
  void dispose() {
    ConnectivityService.instance.dispose();
    SyncService.instance.dispose();
    super.dispose();
  }

  void _setupConnectivityListener() {
    ConnectivityService.instance.addListener(_onConnectivityChanged);
  }

  void _onConnectivityChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _setupAutoSync() {
    SyncService.instance.setupAutoSync();
  }

  void _checkOverdueTasks() async {
    await Future.delayed(const Duration(seconds: 1));
    
    final overdueTasks = await DatabaseService.instance.getOverdueTasks();
    
    if (overdueTasks.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ ${overdueTasks.length} tarefa(s) vencida(s)'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Ver',
            textColor: Colors.white,
            onPressed: () {
              setState(() => _filter = 'pending');
            },
          ),
        ),
      );
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      final List<Task> tasks = await DatabaseService.instance.readAll();
      
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _syncTasks() async {
    final success = await SyncService.instance.forceSync();
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sincronização concluída!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Falha na sincronização'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Task> get _filteredTasks {
    switch (_filter) {
      case 'pending':
        return _tasks.where((t) => !t.completed).toList();
      case 'completed':
        return _tasks.where((t) => t.completed).toList();
      case 'pending_sync':
        return _tasks.where((t) => !t.synced).toList();
      default:
        return _tasks;
    }
  }

  Map<String, int> get _statistics {
    final int total = _tasks.length;
    final int completed = _tasks.where((t) => t.completed).length;
    final int pending = total - completed;
    final int overdue = _tasks.where((t) => t.isOverdue).length;
    final int pendingSync = _tasks.where((t) => !t.synced).length;
    
    return {
      'total': total,
      'completed': completed,
      'pending': pending,
      'overdue': overdue,
      'pending_sync': pendingSync,
    };
  }

  Future<void> _deleteTask(Task task) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja deletar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (ConnectivityService.instance.isOnline) {
          await DatabaseService.instance.delete(task.id!);
        } else {
          await DatabaseService.instance.deleteOffline(task.id!);
        }
        
        await _loadTasks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Tarefa deletada'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleComplete(Task task) async {
    try {
      final Task updated = task.copyWith(
        completed: !task.completed,
        completedAt: !task.completed ? DateTime.now() : null,
        completedBy: !task.completed ? 'manual' : null,
        updatedAt: DateTime.now(),
        synced: ConnectivityService.instance.isOnline,
      );

      if (ConnectivityService.instance.isOnline) {
        await DatabaseService.instance.update(updated);
      } else {
        await DatabaseService.instance.updateOffline(updated);
      }
      
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openTaskForm([Task? task]) async {
    final bool? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFormScreen(task: task),
      ),
    );

    if (result == true) {
      await _loadTasks();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, int> stats = _statistics;
    final List<Task> filteredTasks = _filteredTasks;
    final isOnline = ConnectivityService.instance.isOnline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager Pro'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (stats['pending_sync']! > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge.count(
                count: stats['pending_sync']!,
                backgroundColor: Colors.orange,
                textColor: Colors.white,
                child: const Icon(Icons.cloud_upload),
              ),
            ),
          
          if (stats['overdue']! > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Badge.count(
                count: stats['overdue']!,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                child: const Icon(Icons.warning_amber),
              ),
            ),
          
          if (SyncService.instance.isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else if (!isOnline && stats['pending_sync']! > 0)
            IconButton(
              onPressed: null,
              icon: const Icon(Icons.cloud_off),
              tooltip: 'Offline - ${stats['pending_sync']} pendentes',
            )
          else if (stats['pending_sync']! > 0)
            IconButton(
              onPressed: _syncTasks,
              icon: const Icon(Icons.sync),
              tooltip: 'Sincronizar ${stats['pending_sync']} itens',
            ),
          
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (String value) {
              setState(() => _filter = value);
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list_alt),
                    SizedBox(width: 8),
                    Text('Todas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(Icons.pending_outlined),
                    SizedBox(width: 8),
                    Text('Pendentes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline),
                    SizedBox(width: 8),
                    Text('Concluídas'),
                  ],
                ),
              ),
              if (stats['pending_sync']! > 0)
                PopupMenuItem(
                  value: 'pending_sync',
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text('Pendentes Sync'),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          stats['pending_sync']!.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectivityStatus(
            onSyncPressed: _syncTasks,
          ),

          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Total',
                  value: stats['total'].toString(),
                  icon: Icons.list_alt,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                _StatItem(
                  label: 'Concluídas',
                  value: stats['completed'].toString(),
                  icon: Icons.check_circle,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.3),
                ),
                _StatItem(
                  label: 'Pendentes',
                  value: stats['pending'].toString(),
                  icon: Icons.pending_actions,
                ),
                if (stats['overdue']! > 0) ...[
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _StatItem(
                    label: 'Vencidas',
                    value: stats['overdue'].toString(),
                    icon: Icons.warning_amber,
                    isWarning: true,
                  ),
                ],
                if (stats['pending_sync']! > 0) ...[
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _StatItem(
                    label: 'Pend. Sync',
                    value: stats['pending_sync'].toString(),
                    icon: Icons.cloud_upload,
                    isWarning: true,
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTasks,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredTasks.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, int index) {
                            final Task task = filteredTasks[index];
                            return TaskCard(
                              task: task,
                              onTap: () => _openTaskForm(task),
                              onDelete: () => _deleteTask(task),
                              onCheckboxChanged: (bool? value) => _toggleComplete(task),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_filter) {
      case 'pending':
        message = '🎉 Nenhuma tarefa pendente!';
        icon = Icons.check_circle_outline;
        break;
      case 'completed':
        message = '📋 Nenhuma tarefa concluída ainda';
        icon = Icons.pending_outlined;
        break;
      case 'pending_sync':
        message = '✅ Todas as tarefas estão sincronizadas!';
        icon = Icons.cloud_done;
        break;
      default:
        message = '📝 Nenhuma tarefa ainda.\nToque em + para criar!';
        icon = Icons.add_task;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isWarning;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon, 
          color: isWarning ? Colors.amber : Colors.white, 
          size: 28
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: isWarning ? Colors.amber : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isWarning ? Colors.amber.shade200 : Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}