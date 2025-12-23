import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final Release release;
  final VoidCallback onDismiss;

  const UpdateDialog({Key? key, required this.release, required this.onDismiss})
    : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdateService _updateService = UpdateService();
  static const platform = MethodChannel('com.example.myproject/update');

  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _isInstalling = false;
  File? _downloadedApk;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.system_update, color: Colors.blue, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Available',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Version ${widget.release.version}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (!_isDownloading && _downloadedApk == null)
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: widget.onDismiss,
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                ],
              ),
              SizedBox(height: 16),

              // Release date
              Text(
                'Released: ${DateFormat('MMM dd, yyyy').format(widget.release.releaseDate)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),

              // Changelog
              Text(
                'What\'s New',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.release.changelog,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SizedBox(height: 16),

              // Download progress indicator (if downloading)
              if (_isDownloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Downloading...',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ],
                ),
                SizedBox(height: 16),
              ]
              // Error message (if any)
              else if (_errorMessage != null) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!_isDownloading && !_isInstalling)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onDismiss,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Later'),
                      ),
                    ),
                  if (!_isDownloading && !_isInstalling) SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _isDownloading || _isInstalling
                              ? null
                              : _handleUpdatePressed,
                      icon: Icon(
                        _downloadedApk != null
                            ? Icons.install_mobile
                            : Icons.download,
                      ),
                      label: Text(
                        _isInstalling
                            ? 'Installing...'
                            : _downloadedApk != null
                            ? 'Install'
                            : 'Download & Install',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        disabledBackgroundColor: Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdatePressed() async {
    if (_downloadedApk != null) {
      await _installApk();
    } else {
      await _downloadAndInstall();
    }
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final apkFile = await _updateService.downloadApk(
        widget.release.downloadUrl,
        onProgress: (received, total) {
          setState(() {
            _downloadProgress = total > 0 ? received / total : 0;
          });
        },
      );

      if (apkFile != null) {
        setState(() {
          _downloadedApk = apkFile;
          _isDownloading = false;
        });

        // Automatically proceed to install after download completes
        await _installApk();
      } else {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Failed to download update. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Download error: ${e.toString()}';
      });
    }
  }

  Future<void> _installApk() async {
    if (_downloadedApk == null) return;

    setState(() {
      _isInstalling = true;
      _errorMessage = null;
    });

    try {
      // Open the APK file for installation using platform intent
      // This will trigger the system installer dialog
      await _openApkInstaller(_downloadedApk!);

      // Note: The actual installation happens outside the app
      // The app may be terminated/restarted by the system
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check the install dialog to complete the update.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isInstalling = false;
        _errorMessage = 'Install error: ${e.toString()}';
      });
    }
  }

  /// Open APK file with system installer using platform channels
  Future<void> _openApkInstaller(File apkFile) async {
    try {
      if (Platform.isAndroid) {
        // Call the Kotlin method channel to install the APK
        final bool result = await platform.invokeMethod('installApk', {
          'apkPath': apkFile.path,
        });

        if (result) {
          // Installation intent triggered successfully
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening installer...'),
                duration: Duration(seconds: 2),
              ),
            );
            // Close the dialog after a short delay
            await Future.delayed(Duration(seconds: 1));
            if (mounted) {
              Navigator.pop(context);
            }
          }
        } else {
          setState(() {
            _errorMessage =
                'Failed to open installer. Please install manually.';
          });
        }
      } else if (Platform.isIOS) {
        // For iOS, show a message to update via App Store
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: Text('Update via App Store'),
                content: Text(
                  'Please update the app via the App Store to get the latest version.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('OK'),
                  ),
                ],
              ),
        );
      }
    } on PlatformException catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unexpected error: ${e.toString()}';
      });
    }
  }
}
