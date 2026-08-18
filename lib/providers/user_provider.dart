import 'package:flutter/material.dart';
import '../data/repositories/user_repository.dart';
import '../models/user.dart';
import 'connectivity_provider.dart';

class UserProvider with ChangeNotifier {
  final UserRepository _repo;

  UserProvider({UserRepository? repository})
    : _repo = repository ?? UserRepository();

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
      _users = await _repo.getAll(
        connectivity: connectivity,
        forceRemote: forceRemote,
      );
    } catch (e) {
      debugPrint('Error loading users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addUser(
    AppUser user, {
    ConnectivityProvider? connectivity,
  }) async {
    await _repo.add(user, connectivity: connectivity);
    await loadUsers(connectivity: connectivity);
  }

  Future<void> updateUser(
    AppUser user, {
    ConnectivityProvider? connectivity,
  }) async {
    if (user.id == null) return;
    await _repo.update(user, connectivity: connectivity);
    await loadUsers(connectivity: connectivity);
  }

  Future<bool> deleteUser(int id, {ConnectivityProvider? connectivity}) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final success = await _repo.deleteById(id, connectivity: connectivity);
      if (success) {
        await loadUsers(connectivity: connectivity);
      }
      return success;
    } else {
      // Admin'ni o'chirishni oldini olish (odatda ID 1, lekin rol bo'yicha tekshiramiz)
      final role = await _repo.getRoleById(id);
      if (role == 'admin') {
        return false;
      }

      await _repo.deleteById(id);
      await loadUsers(connectivity: connectivity);
      return true;
    }
  }
}
