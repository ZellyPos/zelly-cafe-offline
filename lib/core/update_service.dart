import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

// ─── GitHub sozlamalari ────────────────────────────────────────────────────────
const _kGithubOwner = 'zellyuz';
const _kGithubRepo  = 'zellyoffline';

const _kApiUrl =
    'https://api.github.com/repos/$_kGithubOwner/$_kGithubRepo/releases/latest';

// ──────────────────────────────────────────────────────────────────────────────

class UpdateInfo {
  final String version;       // '1.2.0'
  final int buildNumber;      // 15
  final String downloadUrl;   // .exe installer URL
  final String releaseNotes;
  final bool mandatory;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.mandatory,
  });

  factory UpdateInfo.fromGithubRelease(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
    final body    = json['body'] as String? ?? '';

    // Assets ichidan .exe faylni topamiz
    final assets = json['assets'] as List<dynamic>? ?? [];
    final exeAsset = assets.firstWhere(
      (a) => (a['name'] as String).endsWith('.exe'),
      orElse: () => <String, dynamic>{},
    );
    final downloadUrl = exeAsset['browser_download_url'] as String? ?? '';

    // Build raqami: tag dan olamiz (masalan v1.2.0+15 → 15)
    int buildNum = 0;
    if (tagName.contains('+')) {
      buildNum = int.tryParse(tagName.split('+').last) ?? 0;
    }

    // Majburiy yangilash: release body da [mandatory] yozilgan bo'lsa
    final mandatory = body.toLowerCase().contains('[mandatory]');

    return UpdateInfo(
      version: tagName.split('+').first,
      buildNumber: buildNum,
      downloadUrl: downloadUrl,
      releaseNotes: body.replaceAll('[mandatory]', '').trim(),
      mandatory: mandatory,
    );
  }
}

class UpdateService {
  static const String _updateCheckKey = 'last_update_check';
  static const Duration _checkInterval = Duration(hours: 1);

  // ── Versiya solishtiruvi ─────────────────────────────────────────────────────

  /// O'rnatilgan ilovada exe yonidagi version.txt dan versiyani o'qiydi.
  /// Agar topilmasa pubspec.yaml dan (development rejim) olinadi.
  static Future<String> getCurrentVersion() async {
    try {
      // 1. exe yonidagi version.txt — o'rnatilgan ilova
      final exeDir = path.dirname(Platform.resolvedExecutable);
      final versionFile = File(path.join(exeDir, 'version.txt'));
      if (await versionFile.exists()) {
        return (await versionFile.readAsString()).trim();
      }
      // 2. pubspec.yaml — development rejim
      final pubspec = File('pubspec.yaml');
      if (await pubspec.exists()) {
        for (final line in await pubspec.readAsLines()) {
          if (line.startsWith('version:')) {
            return line.split(':')[1].trim().split('+')[0];
          }
        }
      }
    } catch (_) {}
    return '1.0.0';
  }

  static bool _isNewer(String latest, String current) {
    List<int> parse(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final l = parse(latest);
    final c = parse(current);
    for (int i = 0; i < 3; i++) {
      final li = i < l.length ? l[i] : 0;
      final ci = i < c.length ? c[i] : 0;
      if (li > ci) return true;
      if (li < ci) return false;
    }
    return false;
  }

  // ── Tekshiruv ─────────────────────────────────────────────────────────────────

  static Future<bool> shouldCheck() async {
    // TEST REJIM: har doim tekshiradi (ishlab bo'lgach o'chiring)
    return true;
    // ignore: dead_code
    final prefs = await SharedPreferences.getInstance();
    final last  = prefs.getInt(_updateCheckKey) ?? 0;
    return (DateTime.now().millisecondsSinceEpoch - last) >
        _checkInterval.inMilliseconds;
  }

  static Future<void> _markChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_updateCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// GitHub Releases API dan eng so'nggi versiyani tekshiradi.
  /// Yangi versiya bo'lsa [UpdateInfo] qaytaradi, aks holda null.
  static Future<UpdateInfo?> checkForUpdates() async {
    // Repo sozlanmagan bo'lsa o'tkazib yuborish
    if (_kGithubOwner == 'YOUR_GITHUB_USERNAME') return null;

    try {
      final response = await http
          .get(
            Uri.parse(_kApiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));

      await _markChecked();

      if (response.statusCode != 200) return null;

      final json     = jsonDecode(response.body) as Map<String, dynamic>;
      final info     = UpdateInfo.fromGithubRelease(json);
      final current  = await getCurrentVersion();

      if (info.downloadUrl.isEmpty) return null;
      if (!_isNewer(info.version, current)) return null;

      return info;
    } catch (e) {
      debugPrint('[UpdateService] check failed: $e');
      return null;
    }
  }

  // ── Yuklab o'rnatish ─────────────────────────────────────────────────────────

  static Future<bool> downloadAndInstall(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final request  = http.Request('GET', Uri.parse(info.downloadUrl));
      final response = await request.send().timeout(const Duration(minutes: 10));

      if (response.statusCode != 200) return false;

      final total     = response.contentLength ?? 0;
      var   received  = 0;
      final bytes     = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }

      // Temp papkaga saqlaymiz
      final installerPath = path.join(
        Directory.systemTemp.path,
        'TezzroSetup_${info.version}.exe',
      );
      await File(installerPath).writeAsBytes(bytes);

      // Installyatorni ishga tushiramiz va ilovani yopoamiz
      await Process.start(
        installerPath,
        ['/SILENT', '/NORESTART'],
        mode: ProcessStartMode.detached,
      );

      return true;
    } catch (e) {
      debugPrint('[UpdateService] download failed: $e');
      return false;
    }
  }

  // ── Dialog ───────────────────────────────────────────────────────────────────

  static Future<void> showUpdateDialog(
    BuildContext context,
    UpdateInfo info,
  ) async {
    final current = await getCurrentVersion();
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: !info.mandatory,
      builder: (ctx) => _UpdateDialog(
        info: info,
        currentVersion: current,
      ),
    );
  }
}

// ─── Update Dialog ─────────────────────────────────────────────────────────────

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final String currentVersion;

  const _UpdateDialog({required this.info, required this.currentVersion});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;  // null = yuklash boshlanmagan
  bool _done = false;
  String? _error;

  Future<void> _startDownload() async {
    setState(() => _progress = 0);

    final ok = await UpdateService.downloadAndInstall(
      widget.info,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    if (ok) {
      setState(() => _done = true);
      // Installyator ishlaydi — ilovani yopoamiz
      Future.delayed(const Duration(seconds: 2), () => exit(0));
    } else {
      setState(() {
        _progress = null;
        _error = 'Yuklab bo\'lmadi. Internet aloqasini tekshiring.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_rounded,
                color: Color(0xFF6366F1), size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Yangi versiya mavjud!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Versiya
            Row(
              children: [
                _versionChip(
                    'Joriy: ${widget.currentVersion}', Colors.grey),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                _versionChip(
                    'Yangi: ${widget.info.version}',
                    const Color(0xFF10B981)),
              ],
            ),
            const SizedBox(height: 16),

            // Release notes
            if (widget.info.releaseNotes.isNotEmpty) ...[
              const Text('O\'zgarishlar:',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Text(widget.info.releaseNotes,
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Majburiy ogohlantirish
            if (widget.info.mandatory)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bu yangilanish majburiy — ilovani ishlatishda davom etish uchun yangilang.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            // Progress bar
            if (_progress != null && !_done) ...[
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Yuklanmoqda...',
                          style: TextStyle(fontSize: 12)),
                      Text(
                        '${(_progress! * 100).toInt()}%',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: theme.colorScheme.onSurface
                          .withValues(alpha: 0.08),
                      color: const Color(0xFF6366F1),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ],

            // Muvaffaqiyatli
            if (_done) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yangilanish o\'rnatilmoqda. Ilova avtomatik yopiladi...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Xato
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: _done || (_progress != null && !_done && _error == null)
          ? null
          : [
              if (!widget.info.mandatory && _progress == null)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Keyinroq'),
                ),
              ElevatedButton.icon(
                onPressed: _progress == null ? _startDownload : null,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Yangilash'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
    );
  }

  Widget _versionChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
