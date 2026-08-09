import 'dart:io';
import 'package:flutter/material.dart';
import '../core/app_logger.dart';
import '../data/repositories/waiter_repository.dart';
import '../models/waiter.dart';
import 'connectivity_provider.dart';

String _actor(ConnectivityProvider? connectivity) {
  final name = connectivity?.currentUser?['name'] as String? ?? 'Admin';
  final role = connectivity?.currentUser?['role'] as String? ?? 'admin';
  return '$name ($role) @ ${Platform.localHostname}';
}

class WaiterProvider with ChangeNotifier {
  final WaiterRepository _repo;

  WaiterProvider({WaiterRepository? repository})
    : _repo = repository ?? WaiterRepository();

  List<Waiter> _waiters = [];
  bool _isLoading = false;

  List<Waiter> get waiters => _waiters;
  bool get isLoading => _isLoading;

  Future<void> loadWaiters({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _waiters = await _repo.getAll(
        connectivity: connectivity,
        forceRemote: forceRemote,
      );
    } catch (e) {
      debugPrint("Error loading waiters: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addWaiter(
    Waiter waiter, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
        final ok = await _repo.add(waiter, connectivity: connectivity);
        if (!ok) {
          AppLogger.e('WaiterProvider', 'Ofitsiant QOSHILMADI (server xato) | Ismi: ${waiter.name} | ${_actor(connectivity)}');
          return 'Serverga qo\'shishda xatolik yuz berdi';
        }
      } else {
        final duplicate = await _repo.findPinDuplicate(waiter.pinCode, excludeId: null);
        if (duplicate != null) {
          AppLogger.w('WaiterProvider', 'Ofitsiant QOSHILMADI (PIN takror) | Ismi: ${waiter.name}, PIN: ${waiter.pinCode} | ${_actor(connectivity)}');
          return 'Bu PIN kod (${waiter.pinCode}) allaqachon "$duplicate" xodimiga biriktirilgan';
        }
        await _repo.add(waiter);
      }
      AppLogger.i('WaiterProvider', 'Ofitsiant QOSHILDI | Ismi: ${waiter.name}, Turi: ${waiter.type}, Qiymati: ${waiter.value} | ${_actor(connectivity)}');
      await loadWaiters(connectivity: connectivity);
      return null;
    } catch (e) {
      AppLogger.e('WaiterProvider', 'Ofitsiant QOSHISHDA XATO | Ismi: ${waiter.name} | ${_actor(connectivity)}', e);
      return 'Xatolik: $e';
    }
  }

  Future<String?> updateWaiter(
    Waiter waiter, {
    ConnectivityProvider? connectivity,
  }) async {
    try {
      if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
        final ok = await _repo.update(waiter, connectivity: connectivity);
        if (!ok) {
          AppLogger.e('WaiterProvider', 'Ofitsiant TAHRIRLANMADI (server xato) | ID: ${waiter.id}, Ismi: ${waiter.name} | ${_actor(connectivity)}');
          return 'Serverda yangilashda xatolik yuz berdi';
        }
      } else {
        final duplicate = await _repo.findPinDuplicate(waiter.pinCode, excludeId: waiter.id);
        if (duplicate != null) {
          AppLogger.w('WaiterProvider', 'Ofitsiant TAHRIRLANMADI (PIN takror) | ID: ${waiter.id}, Ismi: ${waiter.name} | ${_actor(connectivity)}');
          return 'Bu PIN kod (${waiter.pinCode}) allaqachon "$duplicate" xodimiga biriktirilgan';
        }
        await _repo.update(waiter);
      }
      AppLogger.i('WaiterProvider', 'Ofitsiant TAHRIRLANDI | ID: ${waiter.id}, Ismi: ${waiter.name}, Turi: ${waiter.type}, Qiymati: ${waiter.value} | ${_actor(connectivity)}');
      await loadWaiters(connectivity: connectivity);
      return null;
    } catch (e) {
      AppLogger.e('WaiterProvider', 'Ofitsiant TAHRIRLASHDA XATO | ID: ${waiter.id}, Ismi: ${waiter.name} | ${_actor(connectivity)}', e);
      return 'Xatolik: $e';
    }
  }

  Future<String?> bulkUpdateCommission({
    required int type,
    required double value,
    int? onlyCurrentType,
    ConnectivityProvider? connectivity,
  }) async {
    try {
      await _repo.bulkUpdateCommission(
        type: type,
        value: value,
        onlyCurrentType: onlyCurrentType,
      );
      final typeLabel = type == 0 ? 'Belgilangan' : 'Foiz';
      AppLogger.i('WaiterProvider', 'OMMAVIY komissiya YANGILANDI | Tur: $typeLabel, Qiymat: $value${onlyCurrentType != null ? ", Faqat tur: $onlyCurrentType" : ""} | ${_actor(connectivity)}');
      await loadWaiters();
      return null;
    } catch (e) {
      AppLogger.e('WaiterProvider', 'OMMAVIY komissiya YANGILASHDA XATO | ${_actor(connectivity)}', e);
      return 'Xatolik: $e';
    }
  }

  Future<String?> bulkUpdatePermissions({
    required List<String> add,    // qo'shiladigan ruxsatlar
    required List<String> remove, // o'chiriladigan ruxsatlar
    int? onlyCurrentType,         // null=hammasi, 0=fixed, 1=percent
    ConnectivityProvider? connectivity,
  }) async {
    try {
      await _repo.bulkUpdatePermissions(
        add: add,
        remove: remove,
        onlyCurrentType: onlyCurrentType,
      );
      AppLogger.i('WaiterProvider', 'OMMAVIY ruxsatlar YANGILANDI | Qo\'shildi: ${add.join(",")}, O\'chirildi: ${remove.join(",")}${onlyCurrentType != null ? ", Faqat tur: $onlyCurrentType" : ""} | ${_actor(connectivity)}');
      await loadWaiters();
      return null;
    } catch (e) {
      AppLogger.e('WaiterProvider', 'OMMAVIY ruxsatlar YANGILASHDA XATO | ${_actor(connectivity)}', e);
      return 'Xatolik: $e';
    }
  }

  Future<bool> deleteWaiter(
    int id, {
    bool isAdmin = false,
    ConnectivityProvider? connectivity,
  }) async {
    final waiterName = _waiters.firstWhere((w) => w.id == id, orElse: () => Waiter(name: 'ID:$id', pinCode: '', type: 0, value: 0)).name;

    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      final success = await _repo.deleteById(id, connectivity: connectivity);
      if (success) {
        AppLogger.i('WaiterProvider', 'Ofitsiant O\'CHIRILDI | ID: $id, Ismi: $waiterName | ${_actor(connectivity)}');
        await loadWaiters(connectivity: connectivity);
      } else {
        AppLogger.e('WaiterProvider', 'Ofitsiant O\'CHIRILMADI (server xato) | ID: $id, Ismi: $waiterName | ${_actor(connectivity)}');
      }
      return success;
    } else {
      if (!isAdmin) {
        AppLogger.w('WaiterProvider', 'Ofitsiant O\'CHIRISHGA RUXSAt YO\'Q | ID: $id, Ismi: $waiterName | ${_actor(connectivity)}');
        return false;
      }

      // Ofitsiantda buyurtmalar bor-yo'qligini tekshirish
      final orderCount = await _repo.countOrdersForWaiter(id);
      if (orderCount > 0) {
        AppLogger.w('WaiterProvider', 'Ofitsiant O\'CHIRILMADI (buyurtmalari bor) | ID: $id, Ismi: $waiterName, Buyurtmalar: $orderCount ta | ${_actor(connectivity)}');
        return false;
      }

      await _repo.deleteById(id);
      AppLogger.i('WaiterProvider', 'Ofitsiant O\'CHIRILDI | ID: $id, Ismi: $waiterName | ${_actor(connectivity)}');
      await loadWaiters(connectivity: connectivity);
      return true;
    }
  }

  Future<Map<String, dynamic>> getWaiterProfileData(
    int waiterId,
    DateTime start,
    DateTime end,
  ) {
    return _repo.getWaiterProfileData(waiterId, start, end);
  }

  Future<void> addSalaryPayment(int waiterId, int amount, String? note, {ConnectivityProvider? connectivity}) async {
    final waiterName = _waiters.firstWhere((w) => w.id == waiterId, orElse: () => Waiter(name: 'ID:$waiterId', pinCode: '', type: 0, value: 0)).name;
    final actor = _actor(connectivity);
    await _repo.addWaiterPayment(
      waiterId: waiterId,
      amount: amount,
      note: note,
      createdBy: actor,
    );
    AppLogger.i('WaiterProvider', 'Maosh TO\'LOVI qo\'shildi | Ofitsiant: $waiterName (ID: $waiterId), Summa: $amount${note != null ? ", Izoh: $note" : ""} | $actor');
  }
}
