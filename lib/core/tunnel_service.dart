import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

enum TunnelStatus { idle, installing, starting, running, error, stopped }

class TunnelService extends ChangeNotifier {
  static final TunnelService _instance = TunnelService._internal();
  factory TunnelService() => _instance;
  TunnelService._internal();

  Process? _process;
  TunnelStatus _status = TunnelStatus.idle;
  String? _tunnelUrl;
  String? _errorMessage;
  String _logs = '';

  TunnelStatus get status => _status;
  String? get tunnelUrl => _tunnelUrl;
  String? get errorMessage => _errorMessage;
  String get logs => _logs;
  bool get isRunning => _status == TunnelStatus.running;

  /// cloudflared o'rnatilganmi tekshirish
  Future<bool> isInstalled() async {
    try {
      final result = await Process.run('cloudflared', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// winget orqali cloudflared ni o'rnatish
  Future<bool> install() async {
    _status = TunnelStatus.installing;
    _addLog('cloudflared o\'rnatilmoqda...');
    notifyListeners();

    try {
      final result = await Process.run(
        'winget',
        ['install', '--id', 'Cloudflare.cloudflared', '-e', '--silent'],
        runInShell: true,
      );
      if (result.exitCode == 0 || result.exitCode == -1978335191) {
        // -1978335191 = already installed (winget kodi)
        _addLog('cloudflared muvaffaqiyatli o\'rnatildi!');
        return true;
      } else {
        _addLog('O\'rnatishda xato: ${result.stderr}');
        return false;
      }
    } catch (e) {
      _addLog('O\'rnatishda istisno: $e');
      return false;
    }
  }

  /// Tunnelni ishga tushirish
  Future<void> start(int port) async {
    if (_status == TunnelStatus.running || _status == TunnelStatus.starting) {
      return;
    }

    _logs = '';
    _tunnelUrl = null;
    _errorMessage = null;
    _status = TunnelStatus.starting;
    _addLog('Cloudflare Tunnel ishga tushirilmoqda...');
    notifyListeners();

    // cloudflared o'rnatilganmi?
    final installed = await isInstalled();
    if (!installed) {
      _addLog('cloudflared topilmadi. O\'rnatilmoqda...');
      final ok = await install();
      if (!ok) {
        _status = TunnelStatus.error;
        _errorMessage = 'cloudflared o\'rnatib bo\'lmadi. Internetni tekshiring.';
        notifyListeners();
        return;
      }
    }

    try {
      _process = await Process.start(
        'cloudflared',
        ['tunnel', '--url', 'http://127.0.0.1:$port'],
        runInShell: true,
      );

      // URL ni stdout dan qidirish
      _process!.stdout.transform(SystemEncoding().decoder).listen((line) {
        _addLog('[OUT] $line');
        _extractUrl(line);
      });

      // URL ni stderr dan qidirish (cloudflared chiqishini stderr ga yozadi)
      _process!.stderr.transform(SystemEncoding().decoder).listen((line) {
        _addLog(line.trim());
        _extractUrl(line);
      });

      // Jarayon tugasa
      _process!.exitCode.then((code) {
        if (_status != TunnelStatus.stopped) {
          _status = TunnelStatus.error;
          _errorMessage = 'Tunnel to\'xtatildi (kod: $code)';
          _tunnelUrl = null;
          notifyListeners();
        }
      });

      // URL 30 soniya ichida topilmasa — timeout
      Future.delayed(const Duration(seconds: 30), () {
        if (_status == TunnelStatus.starting) {
          _status = TunnelStatus.error;
          _errorMessage = 'URL olishda vaqt tugadi. Internetni tekshiring.';
          notifyListeners();
        }
      });
    } catch (e) {
      _status = TunnelStatus.error;
      _errorMessage = 'cloudflared ishga tushirib bo\'lmadi: $e';
      notifyListeners();
    }
  }

  /// URL ni log satridan ajratib olish
  void _extractUrl(String line) {
    // cloudflared chiqishidagi URL formatları:
    // "https://xxxx.trycloudflare.com"
    final regex = RegExp(r'https://[a-zA-Z0-9\-]+\.trycloudflare\.com');
    final match = regex.firstMatch(line);
    if (match != null && _tunnelUrl == null) {
      _tunnelUrl = match.group(0);
      _status = TunnelStatus.running;
      _addLog('✅ Tunnel tayyor: $_tunnelUrl');
      notifyListeners();
    }
  }

  /// Tunnelni to'xtatish
  Future<void> stop() async {
    _status = TunnelStatus.stopped;
    _process?.kill();
    _process = null;
    _tunnelUrl = null;
    _addLog('Tunnel to\'xtatildi.');
    notifyListeners();
  }

  void _addLog(String line) {
    if (line.trim().isEmpty) return;
    final lines = _logs.split('\n');
    if (lines.length > 100) {
      // Faqat oxirgi 100 satr saqlanadi
      _logs = lines.skip(lines.length - 100).join('\n');
    }
    _logs += '${line.trim()}\n';
  }
}
