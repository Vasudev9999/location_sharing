import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class Release {
  final String version;
  final String downloadUrl;
  final String changelog;
  final DateTime releaseDate;

  Release({
    required this.version,
    required this.downloadUrl,
    required this.changelog,
    required this.releaseDate,
  });

  factory Release.fromJson(Map<String, dynamic> json) {
    return Release(
      version: json['tag_name'] ?? 'unknown',
      downloadUrl: _getApkDownloadUrl(json['assets'] ?? []),
      changelog: json['body'] ?? 'No changes provided',
      releaseDate:
          DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
    );
  }

  static String _getApkDownloadUrl(List<dynamic> assets) {
    for (var asset in assets) {
      if (asset['name']?.endsWith('.apk') ?? false) {
        return asset['browser_download_url'] ?? '';
      }
    }
    return '';
  }
}

class UpdateService {
  static const String githubRepo = 'Vasudev9999/location_sharing';
  static const String githubApiUrl =
      'https://api.github.com/repos/$githubRepo/releases/latest';
  static const platform = MethodChannel('com.example.myproject/update');

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Check for new release on GitHub
  Future<Release?> checkForUpdate() async {
    try {
      final response = await _dio.get(githubApiUrl);
      if (response.statusCode == 200) {
        final release = Release.fromJson(response.data);
        final isNewer = await _isNewerVersion(release.version);
        return isNewer ? release : null;
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
    return null;
  }

  /// Compare version strings (e.g., "1.28" vs "1.0.0+1")
  /// Now reads actual app version from pubspec.yaml (set at build time)
  Future<bool> _isNewerVersion(String remoteVersion) async {
    try {
      // Get the actual app version from the built app (set in pubspec.yaml)
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersionString = packageInfo.version;
      print(
        'Comparing versions - Local: $localVersionString, Remote: $remoteVersion',
      );

      final remote = _parseVersion(remoteVersion);
      final local = _parseVersion(localVersionString);

      for (
        int i = 0;
        i < (remote.length > local.length ? remote.length : local.length);
        i++
      ) {
        final r = i < remote.length ? remote[i] : 0;
        final l = i < local.length ? local[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (e) {
      print('Error parsing version: $e');
      return false;
    }
  }

  List<int> _parseVersion(String versionString) {
    // Remove 'v' prefix if present (e.g., "v1.28" -> "1.28")
    var cleaned = versionString.replaceFirst(RegExp(r'^v'), '');
    // Remove build number (e.g., "+1" from "1.0.0+1")
    final basePart = cleaned.split('+').first;
    return basePart.split('.').map((part) {
      return int.tryParse(part) ?? 0;
    }).toList();
  }

  /// Download APK file with progress callback
  Future<File?> downloadApk(
    String url, {
    required Function(int received, int total) onProgress,
  }) async {
    try {
      // Get the app's cache directory (which FileProvider is configured to access)
      final cacheDir = await getApplicationCacheDirectory();
      final apkFile = File('${cacheDir.path}/update.apk');

      await _dio.download(
        url,
        apkFile.path,
        onReceiveProgress: (received, total) {
          onProgress(received, total);
        },
      );

      return apkFile;
    } catch (e) {
      print('Error downloading APK: $e');
      return null;
    }
  }

  /// Install APK using platform channel
  Future<bool> installApk(File apkFile) async {
    try {
      if (!Platform.isAndroid) {
        print('APK installation is only supported on Android');
        return false;
      }

      if (!apkFile.existsSync()) {
        print('APK file does not exist: ${apkFile.path}');
        return false;
      }

      // Use platform channel to install APK via Android's package installer
      final result = await platform.invokeMethod('installApk', {
        'apkPath': apkFile.path,
      });

      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to install APK: ${e.message}');
      // Fallback: try using 'am install' command
      try {
        final processResult = await Process.run('am', [
          'install',
          '-r',
          '-i',
          'com.android.packageinstaller',
          apkFile.path,
        ], runInShell: true);
        return processResult.exitCode == 0;
      } catch (fallbackError) {
        print('Fallback install also failed: $fallbackError');
        return false;
      }
    } catch (e) {
      print('Error installing APK: $e');
      return false;
    }
  }

  /// Open APK file with system installer (better UX)
  Future<void> openApkForInstall(File apkFile) async {
    try {
      if (!Platform.isAndroid) return;

      if (!apkFile.existsSync()) {
        print('APK file does not exist: ${apkFile.path}');
        return;
      }

      // Try platform channel first
      try {
        await platform.invokeMethod('openApkInstaller', {
          'apkPath': apkFile.path,
        });
      } on PlatformException catch (_) {
        // Fallback: try to open with file manager
        // This approach relies on system handling of APK files
        print('Platform channel not available, using fallback');
      }
    } catch (e) {
      print('Error opening APK: $e');
    }
  }
}
