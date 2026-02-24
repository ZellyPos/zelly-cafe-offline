import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class UpdateInfo {
  final String version;
  final int buildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool mandatory;
  final String minSupportedVersion;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.mandatory,
    required this.minSupportedVersion,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '',
      buildNumber: json['build_number'] ?? 0,
      downloadUrl: json['download_url'] ?? '',
      releaseNotes: json['release_notes'] ?? '',
      mandatory: json['mandatory'] ?? false,
      minSupportedVersion: json['min_supported_version'] ?? '1.0.0',
    );
  }
}

class UpdateService {
  static const String _versionUrl = 'https://your-server.com/version.json';
  static const String _updateCheckKey = 'last_update_check';
  static const Duration _checkInterval = Duration(
    hours: 1,
  ); // Har soatda tekshirish

  static Future<bool> shouldCheckForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_updateCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    return (now - lastCheck) > _checkInterval.inMilliseconds;
  }

  static Future<void> markUpdateChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_updateCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      if (!await shouldCheckForUpdates()) return null;

      // Python FastAPI serverga POST request
      final response = await http
          .post(
            Uri.parse('https://your-server.com/check'),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'ZellyPOS/${await _getCurrentVersion()}',
            },
            body: json.encode({
              'current_version': await _getCurrentVersion(),
              'platform': Platform.operatingSystem,
              'architecture': 'x64',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        await markUpdateChecked();

        if (data['update_available'] == true && data['update_info'] != null) {
          final updateInfo = UpdateInfo.fromJson(data['update_info']);
          return updateInfo;
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  static Future<String> _getCurrentVersion() async {
    // pubspec.yaml dan o'qish
    try {
      final file = File('pubspec.yaml');
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.startsWith('version:')) {
            final versionLine = line.split(':')[1].trim();
            return versionLine.split('+')[0];
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to read version: $e');
    }
    return '1.0.0'; // fallback
  }

  static bool _isNewerVersion(String newVersion, String currentVersion) {
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    final newParts = newVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  static Future<bool> downloadAndInstallUpdate(UpdateInfo updateInfo) async {
    try {
      // Updater.exe ni yuklash
      final updaterUrl = updateInfo.downloadUrl;
      final response = await http.get(Uri.parse(updaterUrl));

      if (response.statusCode == 200) {
        // Temporary faylga saqlash
        final tempDir = Directory.systemTemp;
        final updaterPath = path.join(tempDir.path, 'updater.exe');

        final updaterFile = File(updaterPath);
        await updaterFile.writeAsBytes(response.bodyBytes);

        // Updater.exe ni ishga tushirish
        if (await updaterFile.exists()) {
          final result = await Process.run(updaterPath, [
            '--app-path',
            Directory.current.path,
            '--update-url',
            updaterUrl,
            '--current-version',
            await _getCurrentVersion(),
            '--target-version',
            updateInfo.version,
          ]);

          return result.exitCode == 0;
        }
      }
    } catch (e) {
      debugPrint('Download failed: $e');
    }
    return false;
  }

  static Future<void> showUpdateDialog(
    BuildContext context,
    UpdateInfo updateInfo,
  ) async {
    final currentVersion = await _getCurrentVersion();

    await showDialog(
      context: context,
      barrierDismissible: !updateInfo.mandatory,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 8),
            Text('Yangilav mavjud!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yangi versiya: ${updateInfo.version}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Joriy versiya: $currentVersion'),
            SizedBox(height: 16),
            Text(
              'O\'zgarishlar:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: SingleChildScrollView(
                child: Text(updateInfo.releaseNotes),
              ),
            ),
            if (updateInfo.mandatory) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu yangilash majburiy!',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!updateInfo.mandatory)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Keyinroq'),
            ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Progress dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Yangilanish yuklanmoqda...'),
                    ],
                  ),
                ),
              );

              final success = await downloadAndInstallUpdate(updateInfo);

              if (context.mounted) {
                Navigator.pop(context); // Progress dialog

                if (success) {
                  // App yopilishi kerak, updater.exe ishlaydi
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: Text('Yangilash'),
                      content: Text(
                        'Ilova yangilanmoqda. Ilova avtomatik ravishda yopiladi va qayta ochiladi.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => exit(0), // App ni yopish
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Yangilashni yuklab bo\'lmadi'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Yangilash'),
          ),
        ],
      ),
    );
  }
}
