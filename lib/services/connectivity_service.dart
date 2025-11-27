import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService with ChangeNotifier {
  static final ConnectivityService instance = ConnectivityService._init();
  
  final Connectivity _connectivity = Connectivity();
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  bool _isOnline = true;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  ConnectivityService._init() {
    _initConnectivity();
  }

  bool get isOnline => _isOnline;
  ConnectivityResult get connectionStatus => _connectionStatus;

  String get connectionStatusText {
    switch (_connectionStatus) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi';
      case ConnectivityResult.mobile:
        return 'Mobile';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Outro';
      default:
        return 'Offline';
    }
  }

  Color get connectionStatusColor {
    return _isOnline ? Colors.green : Colors.orange;
  }

  IconData get connectionStatusIcon {
    return _isOnline ? Icons.cloud_done : Icons.cloud_off;
  }

  Future<void> _initConnectivity() async {
    try {
      _connectionStatus = await _connectivity.checkConnectivity();
      _updateConnectionStatus(_connectionStatus);
      
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectionStatus,
      );
    } catch (e) {
      print('❌ Erro ao inicializar conectividade: $e');
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    _connectionStatus = result;
    _isOnline = result != ConnectivityResult.none;
    
    print('🌐 Status de conectividade: $result (Online: $_isOnline)');
    notifyListeners();
  }

  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
}