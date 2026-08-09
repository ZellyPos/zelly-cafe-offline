import 'dart:io';
import 'package:flutter/material.dart';
import '../core/app_logger.dart';
import '../data/repositories/location_repository.dart';
import '../models/location.dart';
import 'connectivity_provider.dart';

String _actor(ConnectivityProvider? connectivity) {
  final name = connectivity?.currentUser?['name'] as String? ?? 'Admin';
  final role = connectivity?.currentUser?['role'] as String? ?? 'admin';
  return '$name ($role) @ ${Platform.localHostname}';
}

class LocationProvider extends ChangeNotifier {
  final LocationRepository _repo;

  LocationProvider({LocationRepository? repository})
    : _repo = repository ?? LocationRepository();

  List<Location> _locations = [];
  bool _isLoading = false;

  List<Location> get locations => _locations;
  bool get isLoading => _isLoading;

  Future<void> loadLocations({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _locations = await _repo.getAll(
        connectivity: connectivity,
        forceRemote: forceRemote,
      );
    } catch (e) {
      debugPrint("Error loading locations: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLocation(
    Location location, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      await _repo.add(location, connectivity: connectivity);
      AppLogger.i('LocationProvider', 'Joy QOSHILDI | Nomi: ${location.name} | ${_actor(connectivity)}');
      await loadLocations(connectivity: connectivity);
    } catch (e) {
      AppLogger.e('LocationProvider', 'Joy QOSHISHDA XATO | Nomi: ${location.name} | ${_actor(connectivity)}', e);
      rethrow;
    }
  }

  Future<void> updateLocation(
    Location location, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      await _repo.update(location, connectivity: connectivity);
      AppLogger.i('LocationProvider', 'Joy TAHRIRLANDI | ID: ${location.id}, Nomi: ${location.name} | ${_actor(connectivity)}');
      await loadLocations(connectivity: connectivity);
    } catch (e) {
      AppLogger.e('LocationProvider', 'Joy TAHRIRLASHDA XATO | ID: ${location.id}, Nomi: ${location.name} | ${_actor(connectivity)}', e);
      rethrow;
    }
  }

  Future<bool> deleteLocation(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    final locationName = _locations.firstWhere((l) => l.id == id, orElse: () => Location(id: id, name: 'ID:$id')).name;

    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final success = await _repo.deleteById(id, connectivity: connectivity);
      if (success) {
        AppLogger.i('LocationProvider', 'Joy O\'CHIRILDI | ID: $id, Nomi: $locationName | ${_actor(connectivity)}');
        await loadLocations(connectivity: connectivity);
      } else {
        AppLogger.e('LocationProvider', 'Joy O\'CHIRILMADI (server xato) | ID: $id, Nomi: $locationName | ${_actor(connectivity)}');
      }
      return success;
    } else {
      // Bu joyga biriktirilgan stollar bor-yo'qligini tekshirish
      final tableCount = await _repo.countTablesForLocation(id);
      if (tableCount > 0) {
        AppLogger.w('LocationProvider', 'Joy O\'CHIRILMADI (stollar bor) | ID: $id, Nomi: $locationName, Stollar: $tableCount ta | ${_actor(connectivity)}');
        return false;
      }

      await _repo.deleteById(id);
      AppLogger.i('LocationProvider', 'Joy O\'CHIRILDI | ID: $id, Nomi: $locationName | ${_actor(connectivity)}');
      await loadLocations();
      return true;
    }
  }
}
