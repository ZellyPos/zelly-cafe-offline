import 'dart:async';
import 'package:flutter/material.dart';
import '../models/shift_models.dart';
import '../repositories/shift_repository.dart';
import '../core/services/shift_service.dart';
import '../core/database_helper.dart';

class ShiftProvider extends ChangeNotifier {
  final ShiftRepository _repo = ShiftRepository();
  final ShiftService _service = ShiftService.instance;

  Shift? _activeShift;
  ShiftSummary? _liveSummary;
  List<CashMovement> _liveMovements = [];
  List<Shift> _history = [];
  bool _isLoading = false;
  String? _error;
  Timer? _summaryRefreshTimer;

  // Auto-shift
  bool _autoShiftEnabled = false;
  String _autoShiftStart = '09:00';
  String _autoShiftEnd = '21:00';
  Timer? _autoShiftTimer;

  // Kun boshlanish vaqti (buyurtma raqami sifirlanadi)
  String _dayResetTime = '';

  // ── Getters ────────────────────────────────────────────────────────────────

  Shift? get activeShift => _activeShift;
  ShiftSummary? get liveSummary => _liveSummary;
  List<CashMovement> get liveMovements => _liveMovements;
  List<Shift> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get hasOpenShift => _activeShift != null;
  bool get autoShiftEnabled => _autoShiftEnabled;
  String get autoShiftStart => _autoShiftStart;
  String get autoShiftEnd => _autoShiftEnd;
  String get dayResetTime => _dayResetTime;

  /// Smenaning ochilganidan beri o'tgan vaqt
  Duration get elapsedTime {
    if (_activeShift == null) return Duration.zero;
    return DateTime.now().difference(_activeShift!.openedAt);
  }

  // ── Inicializatsiya ────────────────────────────────────────────────────────

  Future<void> init() async {
    _setLoading(true);
    try {
      _activeShift = await _repo.getOpenShift();
      await _loadAutoShiftSettings();
      if (_autoShiftEnabled) {
        _startAutoShiftTimer();
        // If shift should be open now but isn't → auto-open immediately
        if (!hasOpenShift) {
          final now = DateTime.now();
          final current = now.hour * 60 + now.minute;
          final start = _parseTimeToMinutes(_autoShiftStart);
          final end = _parseTimeToMinutes(_autoShiftEnd);
          if (current >= start && current < end) {
            await _autoOpenShift();
          }
        }
      }
      if (_activeShift != null) {
        await _refreshLiveSummary();
        _startPeriodicRefresh();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ── Smena ochish ──────────────────────────────────────────────────────────

  Future<void> openShift(double openingCash, int userId) async {
    _setLoading(true);
    _error = null;
    try {
      await _service.openShift(openingCash, userId);
      _activeShift = await _repo.getOpenShift();
      _liveSummary = null;
      _liveMovements = [];
      await _refreshLiveSummary();
      _startPeriodicRefresh();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ── Smena yopish ──────────────────────────────────────────────────────────

  /// Yopishdan oldin to'liq hisobot generatsiyasi (UI ga ko'rsatish uchun)
  Future<ShiftReport> prepareCloseReport(double countedCash) async {
    if (_activeShift == null) throw Exception('Ochiq smena mavjud emas');
    final summary = _liveSummary ?? await _repo.getShiftSalesSummary(_activeShift!.id!);
    return _service.generateShiftReport(
      shift: _activeShift!,
      countedCash: countedCash,
      expectedCash: summary.expectedCashBalance,
    );
  }

  /// Smenani rasmiy yopish
  Future<ShiftReport> closeShift(
    double countedCash,
    int userId,
    String? notes,
  ) async {
    if (_activeShift == null) throw Exception('Ochiq smena mavjud emas');
    _setLoading(true);
    _error = null;
    try {
      final summary = _liveSummary ?? await _repo.getShiftSalesSummary(_activeShift!.id!);
      final report = await _service.generateShiftReport(
        shift: _activeShift!,
        countedCash: countedCash,
        expectedCash: summary.expectedCashBalance,
      );
      await _service.closeShift(countedCash, userId, notes);
      _stopPeriodicRefresh();
      _activeShift = null;
      _liveSummary = null;
      _liveMovements = [];
      await loadHistory();
      return report;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ── Kassa harakatlari ─────────────────────────────────────────────────────

  Future<void> addMovement({
    required double amount,
    required String type,
    required String reason,
    String? note,
    required int userId,
  }) async {
    _error = null;
    try {
      await _service.addCashMovement(
        amount: amount,
        type: type,
        reason: reason,
        note: note,
        userId: userId,
      );
      await _refreshLiveSummary();
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  // ── Tarix ─────────────────────────────────────────────────────────────────

  Future<void> loadHistory() async {
    try {
      _history = await _repo.getShiftHistory(limit: 60);
      notifyListeners();
    } catch (_) {}
  }

  Future<ShiftReport> getHistoryReport(Shift shift) async {
    final summary = await _repo.getShiftSalesSummary(shift.id!);
    return _service.generateShiftReport(
      shift: shift,
      countedCash: shift.countedCash ?? 0,
      expectedCash: summary.expectedCashBalance,
    );
  }

  // ── Live refresh ──────────────────────────────────────────────────────────

  Future<void> _refreshLiveSummary() async {
    if (_activeShift == null) return;
    try {
      _liveSummary = await _repo.getShiftSalesSummary(_activeShift!.id!);
      _liveMovements = await _repo.getShiftMovements(_activeShift!.id!);
      notifyListeners();
    } catch (_) {}
  }

  /// Majburiy yangilash (tashqaridan chaqirish uchun — order yopilgandan keyin)
  Future<void> refresh() => _refreshLiveSummary();

  void _startPeriodicRefresh() {
    _summaryRefreshTimer?.cancel();
    _summaryRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshLiveSummary(),
    );
  }

  void _stopPeriodicRefresh() {
    _summaryRefreshTimer?.cancel();
    _summaryRefreshTimer = null;
  }

  // ── Avtomatik smena ───────────────────────────────────────────────────────

  Future<void> _loadAutoShiftSettings() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'settings',
      where: "key IN ('auto_shift_enabled', 'auto_shift_start', 'auto_shift_end', 'day_reset_time')",
    );
    for (final row in rows) {
      final key = row['key'] as String;
      final val = row['value'] as String? ?? '';
      switch (key) {
        case 'auto_shift_enabled':
          _autoShiftEnabled = val == '1';
          break;
        case 'auto_shift_start':
          if (val.isNotEmpty) _autoShiftStart = val;
          break;
        case 'auto_shift_end':
          if (val.isNotEmpty) _autoShiftEnd = val;
          break;
        case 'day_reset_time':
          _dayResetTime = val;
          break;
      }
    }
  }

  Future<void> saveAutoShiftSettings({
    required bool enabled,
    required String start,
    required String end,
    required String dayResetTime,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      ['auto_shift_enabled', enabled ? '1' : '0'],
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      ['auto_shift_start', start],
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      ['day_reset_time', dayResetTime],
    );
    _dayResetTime = dayResetTime;
    await db.rawInsert(
      'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
      ['auto_shift_end', end],
    );
    _autoShiftEnabled = enabled;
    _autoShiftStart = start;
    _autoShiftEnd = end;
    if (enabled) {
      _startAutoShiftTimer();
    } else {
      _stopAutoShiftTimer();
    }
    notifyListeners();
  }

  void _startAutoShiftTimer() {
    _autoShiftTimer?.cancel();
    _autoShiftTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkAutoShift(),
    );
  }

  void _stopAutoShiftTimer() {
    _autoShiftTimer?.cancel();
    _autoShiftTimer = null;
  }

  void _checkAutoShift() {
    if (!_autoShiftEnabled) return;
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final currentTime = '$hh:$mm';

    if (currentTime == _autoShiftStart && !hasOpenShift) {
      _autoOpenShift();
    } else if (currentTime == _autoShiftEnd && hasOpenShift) {
      _autoCloseShift();
    }
  }

  Future<void> _autoOpenShift() async {
    try {
      // Use first admin user; fall back to 0 (system) if none found
      final db = await DatabaseHelper.instance.database;
      final adminRes = await db.query(
        'users',
        where: "role = 'admin' AND is_active = 1",
        limit: 1,
      );
      final userId = adminRes.isNotEmpty ? (adminRes.first['id'] as int) : 0;

      await _service.openShift(0, userId);
      _activeShift = await _repo.getOpenShift();
      _liveSummary = null;
      _liveMovements = [];
      await _refreshLiveSummary();
      _startPeriodicRefresh();
      notifyListeners();
      debugPrint('[AutoShift] Smena avtomatik ochildi: $_autoShiftStart');
    } catch (e) {
      debugPrint('[AutoShift] Auto-open xatosi: $e');
    }
  }

  Future<void> _autoCloseShift() async {
    if (_activeShift == null) return;
    try {
      final summary = _liveSummary ??
          await _repo.getShiftSalesSummary(_activeShift!.id!);
      await _service.closeShift(
        summary.expectedCashBalance,
        0,
        'Avtomatik yopildi ($_autoShiftEnd)',
      );
      _stopPeriodicRefresh();
      _activeShift = null;
      _liveSummary = null;
      _liveMovements = [];
      await loadHistory();
      notifyListeners();
      debugPrint('[AutoShift] Smena avtomatik yopildi: $_autoShiftEnd');
    } catch (e) {
      debugPrint('[AutoShift] Auto-close xatosi: $e');
    }
  }

  int _parseTimeToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  // ── Yordamchi ─────────────────────────────────────────────────────────────

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPeriodicRefresh();
    _stopAutoShiftTimer();
    super.dispose();
  }
}
