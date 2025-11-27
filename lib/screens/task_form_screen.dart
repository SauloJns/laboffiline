import 'dart:io';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../services/camera_service.dart';
import '../services/location_service.dart';
import '../widgets/location_picker.dart';
import '../services/connectivity_service.dart';
import '../widgets/photo_gallery.dart';
import '../screens/photo_viewer_screen.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;

  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _priority = 'medium';
  bool _completed = false;
  bool _isLoading = false;
  
  List<String> _photoPaths = [];
  double? _latitude;
  double? _longitude;
  String? _locationName;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _priority = widget.task!.priority;
      _completed = widget.task!.completed;
      _photoPaths = List.from(widget.task!.photoPaths);
      _latitude = widget.task!.latitude;
      _longitude = widget.task!.longitude;
      _locationName = widget.task!.locationName;
      _dueDate = widget.task!.dueDate;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final photoPath = await CameraService.instance.takePicture(context);
    
    if (photoPath != null && mounted) {
      setState(() => _photoPaths.add(photoPath));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📷 Foto capturada e adicionada!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final photoPath = await CameraService.instance.pickFromGallery(context);
    
    if (photoPath != null && mounted) {
      setState(() => _photoPaths.add(photoPath));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🖼️ Foto adicionada da galeria!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickMultipleFromGallery() async {
    final List<String>? photoPaths = await CameraService.instance.pickMultipleFromGallery(context);
    
    if (photoPaths != null && photoPaths.isNotEmpty && mounted) {
      setState(() => _photoPaths.addAll(photoPaths));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🖼️ ${photoPaths.length} foto(s) adicionada(s)!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _removePhoto(int index) {
    if (index >= 0 && index < _photoPaths.length) {
      setState(() {
        _photoPaths.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Foto removida')),
      );
    }
  }

  void _viewPhoto(int index) {
    if (index < 0 || index >= _photoPaths.length) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerScreen(
          photoPaths: _photoPaths,
          initialIndex: index,
        ),
      ),
    );
  }

  void _clearAllPhotos() {
    if (_photoPaths.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover todas as fotos?'),
        content: Text('Deseja remover todas as ${_photoPaths.length} fotos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _photoPaths.clear());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🗑️ Todas as fotos removidas')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover Todas'),
          ),
        ],
      ),
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: LocationPicker(
            initialLatitude: _latitude,
            initialLongitude: _longitude,
            initialAddress: _locationName,
            onLocationSelected: (lat, lon, address) {
              setState(() {
                _latitude = lat;
                _longitude = lon;
                _locationName = address;
              });
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _removeLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📍 Localização removida')),
    );
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  void _removeDueDate() {
    setState(() => _dueDate = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📅 Data removida')),
    );
  }

 Future<void> _saveTask() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    final isOnline = ConnectivityService.instance.isOnline;
    
    if (widget.task == null) {
      final newTask = Task(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        completed: _completed,
        photoPaths: _photoPaths,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationName,
        dueDate: _dueDate,
        synced: isOnline, // Sincronizar se online
      );

      if (isOnline) {
        await DatabaseService.instance.create(newTask);
      } else {
        await DatabaseService.instance.createOffline(newTask);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Tarefa criada ${isOnline ? '' : '(offline)'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      final updatedTask = widget.task!.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        completed: _completed,
        photoPaths: _photoPaths,
        latitude: _latitude,
        longitude: _longitude,
        locationName: _locationName,
        dueDate: _dueDate,
        updatedAt: DateTime.now(),
        synced: isOnline,
      );

      if (isOnline) {
        await DatabaseService.instance.update(updatedTask);
      } else {
        await DatabaseService.instance.updateOffline(updatedTask);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Tarefa atualizada ${isOnline ? '' : '(offline)'}'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }

    if (mounted) Navigator.pop(context, true);
    
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título *',
                        hintText: 'Ex: Estudar Flutter',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Digite um título';
                        }
                        if (value.trim().length < 3) {
                          return 'Mínimo 3 caracteres';
                        }
                        return null;
                      },
                      maxLength: 100,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText: 'Detalhes...',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                        prefixIcon: Icon(Icons.flag),
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('🟢 Baixa')),
                        DropdownMenuItem(value: 'medium', child: Text('🟡 Média')),
                        DropdownMenuItem(value: 'high', child: Text('🟠 Alta')),
                        DropdownMenuItem(value: 'urgent', child: Text('🔴 Urgente')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _priority = value);
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Vencimento',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_dueDate != null)
                          TextButton.icon(
                            onPressed: _removeDueDate,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remover'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    if (_dueDate != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today, color: Colors.blue),
                          title: Text(_formatDate(_dueDate!)),
                          subtitle: _buildDueDateStatus(),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _selectDueDate,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _selectDueDate,
                        icon: const Icon(Icons.calendar_today),
                        label: const Text('Definir Data de Vencimento'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: const Text('Tarefa Completa'),
                      subtitle: Text(_completed ? 'Sim' : 'Não'),
                      value: _completed,
                      onChanged: (value) => setState(() => _completed = value),
                      activeColor: Colors.green,
                      secondary: Icon(
                        _completed ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: _completed ? Colors.green : Colors.grey,
                      ),
                    ),
                    
                    const Divider(height: 32),
                    
                    Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Fotos',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_photoPaths.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_photoPaths.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (_photoPaths.isNotEmpty)
                          TextButton.icon(
                            onPressed: _clearAllPhotos,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Limpar Todas'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    PhotoGallery(
                      photoPaths: _photoPaths,
                      onPhotoTap: _viewPhoto,
                      onPhotoDelete: _removePhoto,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _takePicture,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Tirar Foto'),
                        ),
                        
                        OutlinedButton.icon(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo),
                          label: const Text('Uma Foto'),
                        ),
                        
                        OutlinedButton.icon(
                          onPressed: _pickMultipleFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Múltiplas'),
                        ),
                      ],
                    ),
                    
                    const Divider(height: 32),
                    
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Localização',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_latitude != null)
                          TextButton.icon(
                            onPressed: _removeLocation,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remover'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    if (_latitude != null && _longitude != null)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.blue),
                          title: Text(_locationName ?? 'Localização salva'),
                          subtitle: Text(
                            LocationService.instance.formatCoordinates(
                              _latitude!,
                              _longitude!,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: _showLocationPicker,
                          ),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _showLocationPicker,
                        icon: const Icon(Icons.add_location),
                        label: const Text('Adicionar Localização'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                    
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveTask,
                      icon: const Icon(Icons.save),
                      label: Text(isEditing ? 'Atualizar' : 'Criar Tarefa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(date.year, date.month, date.day);
    
    if (taskDate == today) {
      return 'Hoje - ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } else if (taskDate == today.add(const Duration(days: 1))) {
      return 'Amanhã - ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  Widget _buildDueDateStatus() {
    if (_dueDate == null) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final due = _dueDate!;
    
    if (_completed) {
      return const Text(
        '✅ Tarefa concluída',
        style: TextStyle(color: Colors.green),
      );
    } else if (due.isBefore(now)) {
      return const Text(
        '🔴 Vencida',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      );
    } else if (due.year == now.year && due.month == now.month && due.day == now.day) {
      return const Text(
        '🟡 Vence hoje',
        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
      );
    } else {
      final difference = due.difference(now).inDays;
      if (difference <= 3) {
        return Text(
          '🟠 Vence em $difference dias',
          style: const TextStyle(color: Colors.orange),
        );
      } else {
        return Text(
          '🟢 Vence em $difference dias',
          style: const TextStyle(color: Colors.green),
        );
      }
    }
  }
}