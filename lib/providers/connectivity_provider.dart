import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database_helper.dart';
import 'package:http/http.dart' as http;
import '../core/server/api_server.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum ConnectivityMode { local, server, client }

class ConnectivityProvider extends ChangeNotifier {
  ConnectivityMode _mode = ConnectivityMode.local;
  String? _serverIp;
  int _port = 8080;
  String? _clientBaseUrl;
  bool _isServerRunning = false;
  String? _authToken;
  Map<String, dynamic>? _currentUser;
  String _connectionStatus = '';
  bool _isSuccess = false;
  String? _lastError;
  String? _localImagesDirPath;

  ConnectivityMode get mode => _mode;
  String? get serverIp => _serverIp;
  int get port => _port;
  String? get clientBaseUrl => _clientBaseUrl;
  bool get isServerRunning => _isServerRunning;
  String? get authToken => _authToken;
  Map<String, dynamic>? get currentUser => _currentUser;
  String get connectionStatus => _connectionStatus;
  bool get isSuccess => _isSuccess;
  String? get lastError => _lastError;

  ConnectivityProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = ConnectivityMode.values[prefs.getInt('connectivity_mode') ?? 0];
    _clientBaseUrl = prefs.getString('client_base_url');
    _port = prefs.getInt('server_port') ?? 8080;

    if (_mode == ConnectivityMode.server) {
      startServer();
    }

    final appDocDir = await getApplicationSupportDirectory();
    _localImagesDirPath = p.join(appDocDir.path, 'product_images');

    notifyListeners();
  }

  Future<void> setMode(ConnectivityMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('connectivity_mode', mode.index);

    if (mode == ConnectivityMode.server) {
      startServer();
    } else {
      stopServer();
    }
    notifyListeners();
  }

  Future<void> startServer() async {
    if (_isServerRunning) return;

    final info = NetworkInfo();
    _serverIp = await info.getWifiIP();

    // Fallback search for IP if wifi info is empty (common on Windows ethernet)
    if (_serverIp == null) {
      // shelf io handles anyIPv4, but we want to show it to user
      // Simple fallback: check common local interfaces
    }

    final success = await ApiServer.start(_port);
    if (success != null) {
      _isServerRunning = true;
      _serverIp = success;
    }
    notifyListeners();
  }

  void stopServer() {
    ApiServer.stop();
    _isServerRunning = false;
    notifyListeners();
  }

  Future<void> setPort(int port) async {
    _port = port;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('server_port', port);
    if (_mode == ConnectivityMode.server) {
      stopServer();
      startServer();
    }
    notifyListeners();
  }

  Future<void> setClientBaseUrl(String url) async {
    _clientBaseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('client_base_url', url);
    notifyListeners();
  }

  Future<void> testConnection() async {
    _connectionStatus = 'Tekshirilmoqda...';
    _isSuccess = false;
    notifyListeners();

    try {
      if (_mode == ConnectivityMode.client) {
        if (_clientBaseUrl == null || !_clientBaseUrl!.startsWith('http')) {
          _connectionStatus =
              'Xato: URL noto‘g‘ri shaklda (http://1.2.3.4:8080)';
          notifyListeners();
          return;
        }
        final response = await http
            .get(Uri.parse('$_clientBaseUrl/locations'))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          _connectionStatus = 'Ulandi! Server ishlamoqda.';
          _isSuccess = true;
        } else {
          _connectionStatus =
              'Xato: Serverdan nojo‘ya javob (${response.statusCode})';
        }
      } else if (_mode == ConnectivityMode.server) {
        if (_isServerRunning) {
          _connectionStatus = 'Server ishlamoqda: $_serverIp:$_port';
          _isSuccess = true;
        } else {
          _connectionStatus = 'Xato: Server ishlamayapti!';
        }
      } else {
        _connectionStatus = 'Lokal rejim: Server talab qilinmaydi.';
        _isSuccess = true;
      }
    } catch (e) {
      _connectionStatus = 'Ulanmadi: $e';
    }
    notifyListeners();
  }

  bool shouldFetchRemote({bool forceRemote = false}) {
    if (forceRemote) return true;
    if (_mode == ConnectivityMode.client) return true;
    if (_currentUser != null && _currentUser!['role'] != 'admin') return true;
    return false;
  }

  void setCurrentUser(Map<String, dynamic>? user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<String?> updateCurrentUserPin(String oldPin, String newPin) async {
    if (_currentUser == null) return "Foydalanuvchi aniqlanmadi";

    // 1. Verify old PIN locally (assuming we have it in _currentUser or database)
    final db = DatabaseHelper.instance;
    final userId = _currentUser!['id'];

    if (userId == null) {
      // For fallback admin account without real ID in DB
      return "Ushbu foydalanuvchi PIN kodini o'zgartira olmaydi. Tizim admini bilan bog'laning.";
    }

    final userInDb = await db.queryByColumn('users', 'id', userId);
    if (userInDb.isEmpty || userInDb.first['pin'] != oldPin) {
      return "Joriy PIN kod noto'g'ri";
    }

    // 2. Check for duplicate PIN across ALL users
    final duplicateCheck = await db.queryByColumn('users', 'pin', newPin);
    if (duplicateCheck.isNotEmpty) {
      final otherUser = duplicateCheck.first;
      if (otherUser['id'] != userId) {
        return "Ushbu PIN kod allaqachon boshqa foydalanuvchi tomonidan ishlatilmoqda";
      }
    }

    // 3. Update PIN in DB
    await db.update('users', {'pin': newPin}, 'id = ?', [userId]);

    // 4. Update local state
    final updatedUser = Map<String, dynamic>.from(_currentUser!);
    updatedUser['pin'] = newPin;
    _currentUser = updatedUser;

    notifyListeners();
    return null; // Success
  }

  // API Methods for Client
  Future<bool> login(String pin) async {
    _lastError = null;
    notifyListeners();

    if (_mode == ConnectivityMode.local) {
      // Logic handled in LoginScreen via AppSettingsProvider for now
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_clientBaseUrl/auth/login'),
            body: jsonEncode({'pin': pin}),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _authToken = data['token'];
        _currentUser = data['user'];
        notifyListeners();
        return true;
      } else {
        _lastError = data['error'] ?? 'Kirishda xatolik yuz berdi';
      }
    } catch (e) {
      _lastError = 'Server bilan ulanishda xatolik: $e';
    }
    notifyListeners();
    return false;
  }

  Future<List<Map<String, dynamic>>> getRemoteData(String path) async {
    try {
      final response = await http
          .get(
            Uri.parse('$_clientBaseUrl$path'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Remote Data Error: $e');
    }
    return [];
  }

  Future<bool> postRemoteData(String path, Map<String, dynamic> data) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_clientBaseUrl$path'),
            body: jsonEncode(data),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Post Remote Data Error: $e');
      return false;
    }
  }

  Future<bool> deleteRemoteData(String path) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$_clientBaseUrl$path'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Delete Remote Data Error: $e');
      return false;
    }
  }

  Future<String?> uploadImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final response = await http
          .post(
            Uri.parse('$_clientBaseUrl/upload/image'),
            body: bytes,
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['fileName'];
      }
    } catch (e) {
      debugPrint('Upload Image Error: $e');
    }
    return null;
  }

  String? getImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;

    // If it's a filename (no slash or drive letter), and we're in client mode
    if (_mode == ConnectivityMode.client &&
        !path.contains('/') &&
        !path.contains('\\')) {
      return '$_clientBaseUrl/uploads/$path';
    }

    // If it's a server and it's just a filename, it might be in our own uploads
    if (_mode == ConnectivityMode.server &&
        !path.contains('/') &&
        !path.contains('\\')) {
      return 'http://localhost:$_port/uploads/$path';
    }

    // Fallback for local/server mode filename resolution to local path
    if (_localImagesDirPath != null &&
        !path.contains('/') &&
        !path.contains('\\')) {
      final localPath = p.join(_localImagesDirPath!, path);
      if (File(localPath).existsSync()) {
        return localPath;
      }
    }

    return path;
  }
}
