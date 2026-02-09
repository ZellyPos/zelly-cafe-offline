import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/location.dart';
import 'connectivity_provider.dart';

class LocationProvider extends ChangeNotifier {
  List<Location> _locations = [];
  bool _isLoading = false;

  List<Location> get locations => _locations;
  bool get isLoading => _isLoading;

  Future<void> loadLocations([ConnectivityProvider? connectivity]) async {
    _isLoading = true;
    notifyListeners();

    final List<Map<String, dynamic>> data;
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final remoteData = await connectivity.getRemoteData('/locations');
      data = List<Map<String, dynamic>>.from(remoteData);
    } else {
      data = await DatabaseHelper.instance.queryAll('locations');
    }
    _locations = data.map((item) => Location.fromMap(item)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addLocation(Location location) async {
    await DatabaseHelper.instance.insert('locations', location.toMap());
    await loadLocations();
  }

  Future<void> updateLocation(Location location) async {
    await DatabaseHelper.instance.update(
      'locations',
      location.toMap(),
      'id = ?',
      [location.id],
    );
    await loadLocations();
  }

  Future<bool> deleteLocation(int id) async {
    // Check if tables exist for this location
    final tables = await DatabaseHelper.instance.queryByColumn(
      'tables',
      'location_id',
      id,
    );
    if (tables.isNotEmpty) {
      return false; // Cannot delete
    }

    await DatabaseHelper.instance.delete('locations', 'id = ?', [id]);
    await loadLocations();
    return true;
  }
}
