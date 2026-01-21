// lib/widgets/permission_settings_card.dart
import 'package:flutter/material.dart';
import '../services/permission_manager.dart';
import '../services/background_service.dart';

/// A card widget to display and manage permissions and background service status
class PermissionSettingsCard extends StatefulWidget {
  const PermissionSettingsCard({Key? key}) : super(key: key);

  @override
  State<PermissionSettingsCard> createState() => _PermissionSettingsCardState();
}

class _PermissionSettingsCardState extends State<PermissionSettingsCard> {
  Map<String, dynamic>? _permissionStatus;
  bool _isServiceRunning = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _isLoading = true);

    final status = await PermissionManager.getPermissionStatus();
    final serviceRunning = await BackgroundLocationService.isRunning();

    setState(() {
      _permissionStatus = status;
      _isServiceRunning = serviceRunning;
      _isLoading = false;
    });
  }

  Future<void> _requestPermissions() async {
    final granted = await PermissionManager.requestAllPermissions(context);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? '✅ All permissions granted'
                : '⚠️ Some permissions were not granted',
          ),
          backgroundColor: granted ? Colors.green : Colors.orange,
        ),
      );

      await _loadStatus();
    }
  }

  Future<void> _toggleService() async {
    if (_isServiceRunning) {
      await BackgroundLocationService.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🛑 Background service stopped')),
        );
      }
    } else {
      await BackgroundLocationService.initialize();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚀 Background service started')),
        );
      }
    }

    await _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final locationGranted = _permissionStatus?['locationGranted'] ?? false;
    final backgroundGranted =
        _permissionStatus?['backgroundLocationGranted'] ?? false;
    final notificationGranted =
        _permissionStatus?['notificationGranted'] ?? false;
    final allGranted = _permissionStatus?['allGranted'] ?? false;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allGranted ? Icons.check_circle : Icons.warning,
                  color: allGranted ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Background Location Service',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Permission status
            _buildPermissionRow(
              'Location',
              locationGranted,
              _permissionStatus?['location'] ?? 'Unknown',
            ),
            _buildPermissionRow(
              'Background Location',
              backgroundGranted,
              backgroundGranted ? 'Granted' : 'Not Granted',
            ),
            _buildPermissionRow(
              'Notifications',
              notificationGranted,
              notificationGranted ? 'Granted' : 'Not Granted',
            ),

            const Divider(height: 24),

            // Service status
            Row(
              children: [
                Icon(
                  _isServiceRunning ? Icons.circle : Icons.circle_outlined,
                  color: _isServiceRunning ? Colors.green : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Service: ${_isServiceRunning ? "Running" : "Stopped"}',
                  style: TextStyle(
                    color: _isServiceRunning ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _requestPermissions,
                    icon: const Icon(Icons.security),
                    label: const Text('Grant Permissions'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: allGranted ? _toggleService : null,
                    icon: Icon(
                      _isServiceRunning ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(_isServiceRunning ? 'Stop' : 'Start'),
                  ),
                ),
              ],
            ),

            if (!allGranted)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'ℹ️ Grant all permissions to enable background location sharing',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRow(String label, bool granted, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(status, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
