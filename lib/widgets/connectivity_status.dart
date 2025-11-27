import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class ConnectivityStatus extends StatelessWidget {
  final VoidCallback? onSyncPressed;

  const ConnectivityStatus({super.key, this.onSyncPressed});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, child) {
        final isOnline = ConnectivityService.instance.isOnline;
        final statusColor = ConnectivityService.instance.connectionStatusColor;
        final statusIcon = ConnectivityService.instance.connectionStatusIcon;
        final statusText = ConnectivityService.instance.connectionStatusText;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: statusColor.withOpacity(0.1),
          child: Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'Online - $statusText' : 'Offline',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              
              // Botão de sincronização quando offline com itens pendentes
              if (!isOnline)
                FutureBuilder<SyncStatus>(
                  future: SyncService.instance.getSyncStatus(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.hasPendingChanges) {
                      return Row(
                        children: [
                          Text(
                            '${snapshot.data!.pendingTasks} pendentes',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.cloud_upload,
                            size: 16,
                            color: Colors.orange,
                          ),
                        ],
                      );
                    }
                    return const SizedBox();
                  },
                ),
              
              if (isOnline && onSyncPressed != null)
                TextButton(
                  onPressed: onSyncPressed,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Sincronizar',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.sync, size: 14),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}