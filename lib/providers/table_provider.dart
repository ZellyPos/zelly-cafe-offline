import 'dart:io';
import 'package:flutter/material.dart';
import '../core/app_logger.dart';
import '../data/repositories/table_repository.dart';
import '../models/table.dart';
import 'connectivity_provider.dart';

String _actor(ConnectivityProvider? connectivity) {
  final name = connectivity?.currentUser?['name'] as String? ?? 'Admin';
  final role = connectivity?.currentUser?['role'] as String? ?? 'admin';
  return '$name ($role) @ ${Platform.localHostname}';
}

class TableProvider extends ChangeNotifier {
  final TableRepository _repo;

  TableProvider({TableRepository? repository})
    : _repo = repository ?? TableRepository();

  List<TableModel> _tables = [];
  bool _isLoading = false;

  List<TableModel> get tables => _tables;
  bool get isLoading => _isLoading;

  Future<void> loadTables({
    ConnectivityProvider? connectivity,
    bool silent = false,
    bool forceRemote = false,
  }) async {
    // Faqat dastlabki yuklashda indikator ko'rsatiladi
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _tables = await _repo.getAllWithOrders(
        connectivity: connectivity,
        forceRemote: forceRemote,
      );
    } catch (e) {
      debugPrint('Error loading tables: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTable(
    TableModel table, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      await _repo.add(table, connectivity: connectivity);
      AppLogger.i('TableProvider', 'Stol QOSHILDI | Nomi: ${table.name}, Joy ID: ${table.locationId}, Narx turi: ${table.pricingType} | ${_actor(connectivity)}');
      await loadTables(connectivity: connectivity);
    } catch (e) {
      AppLogger.e('TableProvider', 'Stol QOSHISHDA XATO | Nomi: ${table.name} | ${_actor(connectivity)}', e);
      rethrow;
    }
  }

  /// Bir vaqtda bir nechta stol yaratadi ([start] dan [end] gacha, ikkalasi ham
  /// kiritilgan). Muvaffaqiyatli yaratilgan stollar sonini qaytaradi.
  Future<int> addTablesBulk({
    required String prefix,
    required int start,
    required int end,
    required int locationId,
    int pricingType = 0,
    double hourlyRate = 0,
    double fixedAmount = 0,
    double servicePercentage = 0,
    ConnectivityProvider? connectivity,
    void Function(int done, int total)? onProgress,
  }) async {
    final total = end - start + 1;
    int done = 0;
    try {
      for (int i = start; i <= end; i++) {
        final name = prefix.isEmpty ? '$i' : '$prefix $i';
        final table = TableModel(
          name: name,
          locationId: locationId,
          status: 0,
          pricingType: pricingType,
          hourlyRate: hourlyRate,
          fixedAmount: fixedAmount,
          servicePercentage: servicePercentage,
        );
        await _repo.add(table, connectivity: connectivity);
        done++;
        onProgress?.call(done, total);
      }
      AppLogger.i('TableProvider', 'OMMAVIY stol QOSHILDI | Prefiks: "${prefix.isEmpty ? "-" : prefix}", $start–$end, Jami: $done ta, Joy ID: $locationId, Narx turi: $pricingType | ${_actor(connectivity)}');
      await loadTables(connectivity: connectivity);
    } catch (e) {
      AppLogger.e('TableProvider', 'OMMAVIY stol QOSHISHDA XATO | $done/$total qo\'shildi | ${_actor(connectivity)}', e);
    }
    return done;
  }

  Future<void> updateTable(
    TableModel table, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      await _repo.updatePreservingOrder(table, connectivity: connectivity);
      AppLogger.i('TableProvider', 'Stol TAHRIRLANDI | ID: ${table.id}, Nomi: ${table.name}, Joy ID: ${table.locationId}, Narx turi: ${table.pricingType} | ${_actor(connectivity)}');
      await loadTables(connectivity: connectivity);
    } catch (e) {
      AppLogger.e('TableProvider', 'Stol TAHRIRLASHDA XATO | ID: ${table.id}, Nomi: ${table.name} | ${_actor(connectivity)}', e);
      rethrow;
    }
  }

  Future<bool> deleteTable(int id, {ConnectivityProvider? connectivity}) async {
    final tableName = _tables.firstWhere((t) => t.id == id, orElse: () => TableModel(name: 'ID:$id', locationId: 0)).name;

    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final success = await _repo.deleteById(id, connectivity: connectivity);
      if (success) {
        AppLogger.i('TableProvider', 'Stol O\'CHIRILDI | ID: $id, Nomi: $tableName | ${_actor(connectivity)}');
        await loadTables(connectivity: connectivity);
      } else {
        AppLogger.e('TableProvider', 'Stol O\'CHIRILMADI (server xato) | ID: $id, Nomi: $tableName | ${_actor(connectivity)}');
      }
      return success;
    } else {
      // Stolda OCHIQ buyurtma bor-yo'qligini tekshirish
      final openOrders = await _repo.countOpenOrders(id);
      if (openOrders > 0) {
        AppLogger.w('TableProvider', 'Stol O\'CHIRILMADI (ochiq buyurtma bor) | ID: $id, Nomi: $tableName | ${_actor(connectivity)}');
        return false;
      }

      await _repo.deleteById(id);
      AppLogger.i('TableProvider', 'Stol O\'CHIRILDI | ID: $id, Nomi: $tableName | ${_actor(connectivity)}');
      await loadTables();
      return true;
    }
  }

  Future<void> updateTableStatus(
    int id,
    int status, {
    ConnectivityProvider? connectivity,
  }) async {
    final tableName = _tables.firstWhere((t) => t.id == id, orElse: () => TableModel(name: 'ID:$id', locationId: 0)).name;
    await _repo.updateStatus(id, status, connectivity: connectivity);
    final statusLabel = status == 0 ? 'bo\'sh' : 'band';
    AppLogger.d('TableProvider', 'Stol holati O\'ZGARTIRILDI | ID: $id, Nomi: $tableName → $statusLabel | ${_actor(connectivity)}');
    await loadTables(connectivity: connectivity);
  }

  Future<void> updateTableLayout(
    int id,
    double x,
    double y,
    double width,
    double height, {
    ConnectivityProvider? connectivity,
  }) async {
    await _repo.updateLayout(id, x, y, width, height, connectivity: connectivity);

    // To'liq qayta yuklamaslik uchun ro'yxatdagi stolni lokal yangilaymiz
    final index = _tables.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tables[index] = _tables[index].copyWith(
        x: x,
        y: y,
        width: width,
        height: height,
      );
      notifyListeners();
    }
  }

  Future<List<TableModel>> getTablesForLocation(int? locationId) async {
    try {
      return await _repo.getTablesForLocation(locationId);
    } catch (e) {
      debugPrint('Error getting tables for location: $e');
      return [];
    }
  }

  Future<String?> bulkUpdatePricing({
    required int pricingType,
    required double value,
    int? onlyLocationId,
    int? onlyCurrentPricingType,
    ConnectivityProvider? connectivity,
  }) async {
    try {
      await _repo.bulkUpdatePricing(
        pricingType: pricingType,
        value: value,
        onlyLocationId: onlyLocationId,
        onlyCurrentPricingType: onlyCurrentPricingType,
      );
      final typeLabels = ['Oddiy', 'Soatlik', 'Belgilangan', 'Xizmat%'];
      final typeLabel = pricingType < typeLabels.length ? typeLabels[pricingType] : '$pricingType';
      AppLogger.i('TableProvider', 'OMMAVIY narx turi YANGILANDI | Tur: $typeLabel, Qiymat: $value${onlyLocationId != null ? ", Joy ID: $onlyLocationId" : ""}${onlyCurrentPricingType != null ? ", Faqat tur: $onlyCurrentPricingType" : ""} | ${_actor(connectivity)}');
      await loadTables();
      return null;
    } catch (e) {
      AppLogger.e('TableProvider', 'OMMAVIY narx turi YANGILASHDA XATO | ${_actor(connectivity)}', e);
      return 'Xatolik: $e';
    }
  }
}
