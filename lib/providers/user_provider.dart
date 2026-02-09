import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/user.dart';

class UserProvider with ChangeNotifier {
  List<AppUser> _users = [];
  bool _isLoading = false;

  List<AppUser> get users => _users;
  List<AppUser> get cashiers =>
      _users.where((u) => u.role == 'cashier').toList();
  bool get isLoading => _isLoading;

  Future<void> loadUsers() async {
    _isLoading = true;
    notifyListeners();

    final data = await DatabaseHelper.instance.queryAll('users');
    _users = data.map((item) => AppUser.fromMap(item)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addUser(AppUser user) async {
    await DatabaseHelper.instance.insert('users', user.toMap());
    await loadUsers();
  }

  Future<void> updateUser(AppUser user) async {
    if (user.id == null) return;
    await DatabaseHelper.instance.update('users', user.toMap(), 'id = ?', [
      user.id,
    ]);
    await loadUsers();
  }

  Future<bool> deleteUser(int id) async {
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
    await loadUsers();
    return true;
  }
}
