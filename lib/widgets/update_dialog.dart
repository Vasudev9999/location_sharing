import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/update_service.dart';
import '../theme/retro_theme.dart';

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
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xE6FFFFFF), // kGlassWhite
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF1A1A1A).withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with accent background
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF2962FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: Color(0xFF2962FF),
                    size: 48,
                  ),
                ),
                SizedBox(height: 24),

                // Title
                Text(
                  'Update Available',
                  style: GoogleFonts.spaceMono(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),

                // Version badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF2962FF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Version ${widget.release.version}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2962FF),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // Download progress (if downloading)
                if (_isDownloading) ...[
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Color(0xFF2962FF).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Downloading...',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                              style: GoogleFonts.spaceMono(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2962FF),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _downloadProgress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withOpacity(0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF2962FF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                ]
                // Error message (if any)
                else if (_errorMessage != null) ...[
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                ],

                // Action buttons
                Row(
                  children: [
                    if (!_isDownloading && !_isInstalling)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onDismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Color(0xFF1A1A1A),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: Color(0xFF1A1A1A).withOpacity(0.2),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Later',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    if (!_isDownloading && !_isInstalling) SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isDownloading || _isInstalling
                                ? null
                                : _handleUpdatePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1A1A1A),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Color(
                            0xFF1A1A1A,
                          ).withOpacity(0.3),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _isInstalling
                              ? 'Installing...'
                              : _downloadedApk != null
                              ? 'Install'
                              : 'Download',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
