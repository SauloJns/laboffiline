import 'package:flutter/material.dart';
import 'services/camera_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'screens/task_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar serviços
  await CameraService.instance.initialize();
  
  ConnectivityService.instance; // Inicializa automaticamente
  SyncService.instance; // Inicializa automaticamente
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager Pro - Offline First',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // Use double value
          ),
        ),
      ),
      home: const TaskListScreen(),
    );
  }
}