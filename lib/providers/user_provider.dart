import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/user.dart';
import 'connectivity_provider.dart';

class UserProvider with ChangeNotifier {
  List<AppUser> _users = [];
  bool _isLoading = false;

  List<AppUser> get users => _users;
  List<AppUser> get cashiers =>
      _users.where((u) => u.role == 'cashier').toList();
  bool get isLoading => _isLoading;

  Future<void> loadUsers({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data;
      if (connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
        final remoteData = await connectivity.getRemoteData('/users');
        data = List<Map<String, dynamic>>.from(remoteData);
      } else {
        data = await DatabaseHelper.instance.queryAll('users');
      }
      _users = data.map((item) => AppUser.fromMap(item)).toList();
    } catch (e) {
      debugPrint("Error loading users: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addUser(
    AppUser user, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/users', user.toMap());
    } else {
      await DatabaseHelper.instance.insert('users', user.toMap());
    }
    await loadUsers(connectivity: connectivity);
  }

  Future<void> updateUser(
    AppUser user, {
    ConnectivityProvider? connectivity,
  }) async {
    if (user.id == null) return;
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/users', user.toMap());
    } else {
      await DatabaseHelper.instance.update('users', user.toMap(), 'id = ?', [
        user.id,
      ]);
    }
    await loadUsers(connectivity: connectivity);
  }

  Future<bool> deleteUser(int id, {ConnectivityProvider? connectivity}) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final success = await connectivity.deleteRemoteData('/users/$id');
      if (success) {
        await loadUsers(connectivity: connectivity);
      }
      return success;
    } else {
      // Prevent deleting Admin (usually ID 1, but let's check role)
      final userRes = await DatabaseHelper.instance.queryByColumn(
        'users',
        'id',
        id,
      );
      if (userRes.isNotEmpty && userRes.first['role'] == 'admin') {
        return false;
      }

      await DatabaseHelper.instance.delete('users', 'id = ?', [id]);
      await loadUsers(connectivity: connectivity);
      return true;
    }
  }
}
