import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Function(bool?) onCheckboxChanged;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onDelete,
    required this.onCheckboxChanged,
  });

  Color _getPriorityColor() {
    switch (task.priority) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.amber;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getPriorityIcon() {
    switch (task.priority) {
      case 'urgent': return Icons.priority_high;
      case 'high': return Icons.arrow_upward;
      case 'medium': return Icons.remove;
      case 'low': return Icons.arrow_downward;
      default: return Icons.flag;
    }
  }

  String _getPriorityLabel() {
    switch (task.priority) {
      case 'urgent': return 'Urgente';
      case 'high': return 'Alta';
      case 'medium': return 'Média';
      case 'low': return 'Baixa';
      default: return 'Normal';
    }
  }

  Future<void> _shareTask() async {
    try {
      await Share.share(task.shareText);
    } catch (e) {
      // Erro silencioso
    }
  }

  Widget _buildSyncStatus() {
    if (task.synced) {
      return const Tooltip(
        message: 'Sincronizado com o servidor',
        child: Icon(Icons.cloud_done, size: 16, color: Colors.green),
      );
    } else if (task.hasSyncError) {
      return Tooltip(
        message: 'Erro de sincronização: ${task.syncError}',
        child: const Icon(Icons.cloud_off, size: 16, color: Colors.red),
      );
    } else {
      return const Tooltip(
        message: 'Aguardando sincronização',
        child: Icon(Icons.cloud_upload, size: 16, color: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color priorityColor = _getPriorityColor();
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.completed 
            ? Colors.grey.shade300 
            : (task.isOverdue ? Colors.red : priorityColor.withOpacity(0.3)),
          width: task.isOverdue ? 3 : 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Checkbox(
                        value: task.completed,
                        onChanged: onCheckboxChanged,
                        activeColor: Colors.green,
                      ),
                      if (task.isPendingSync)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: _buildSyncStatus(),
                        ),
                    ],
                  ),
                  
                  const SizedBox(width: 8),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: task.completed 
                                    ? TextDecoration.lineThrough 
                                    : null,
                                  color: task.completed 
                                    ? Colors.grey 
                                    : (task.isOverdue ? Colors.red : Colors.black87),
                                ),
                              ),
                            ),
                            if (task.isOverdue)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.warning_amber,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: task.completed 
                                ? Colors.grey 
                                : Colors.black54,
                            ),
                          ),
                        ],
                        
                        if (task.dueDate != null && !task.completed) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getDueDateColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getDueDateColor().withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: _getDueDateColor(),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _getDueDateText(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _getDueDateColor(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 8),
                        
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: priorityColor.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getPriorityIcon(),
                                    size: 14,
                                    color: priorityColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getPriorityLabel(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: priorityColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            if (task.hasPhotos)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.photo_library,
                                      size: 14,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${task.photoPaths.length}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            if (task.hasLocation)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.purple.withOpacity(0.5),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Colors.purple,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Local',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            
                            if (task.completed && task.wasCompletedByShake)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.5),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.vibration,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Shake',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Status de sincronização
                            if (!task.synced)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildSyncStatus(),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Pendente',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Column(
                    children: [
                      IconButton(
                        onPressed: _shareTask,
                        icon: const Icon(Icons.share),
                        color: Colors.blue,
                        tooltip: 'Compartilhar',
                        iconSize: 20,
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                        tooltip: 'Deletar',
                        iconSize: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            if (task.hasPhotos)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: task.photoPaths.length,
                    itemBuilder: (context, index) {
                      return _buildPhotoPreview(task.photoPaths[index], index, context);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreview(String path, int index, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getDueDateColor() {
    if (task.completed) return Colors.green;
    if (task.isOverdue) return Colors.red;
    if (task.isDueToday) return Colors.orange;
    if (task.isDueSoon) return Colors.amber;
    return Colors.green;
  }

  String _getDueDateText() {
    if (task.completed) return 'Concluída';
    if (task.isOverdue) {
      final days = DateTime.now().difference(task.dueDate!).inDays;
      return 'Vencida há ${days + 1} dias';
    }
    if (task.isDueToday) return 'Vence hoje';
    
    final days = task.dueDate!.difference(DateTime.now()).inDays;
    return 'Vence em $days dias';
  }
}