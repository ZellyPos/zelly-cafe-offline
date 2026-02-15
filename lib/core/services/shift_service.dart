import '../database_helper.dart';
import '../../models/shift_models.dart';
import '../../repositories/shift_repository.dart';

/// Smena bilan bog'liq biznes logikasini boshqarish uchun servis
class ShiftService {
  final ShiftRepository _repo = ShiftRepository();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  static final ShiftService instance = ShiftService._internal();
  ShiftService._internal();

  // --- Smenani Boshqarish ---

  /// Yangi smena ochish. Agar ochiq smena bo'lsa xatolik qaytaradi.
  Future<int> openShift(double openingCash, int userId) async {
    final activeShift = await _repo.getOpenShift();
    if (activeShift != null) {
      throw Exception('Allaqachon ochiq smena mavjud (ID: ${activeShift.id})');
    }

    final newShift = Shift(
      openedAt: DateTime.now(),
      openedBy: userId,
      openingCash: openingCash,
      status: 0, // Ochiq
    );

    return await _repo.openShift(newShift);
  }

  /// Smenani yopish. Yakuniy hisob-kitoblarni amalga oshiradi.
  Future<void> closeShift(double countedCash, int userId, String? notes) async {
    final activeShift = await _repo.getOpenShift();
    if (activeShift == null) {
      throw Exception('Yopish uchun ochiq smena topilmadi');
    }

    // Sotuvlar va kassa harakatlari bo'yicha hisobotni olish
    final summary = await _repo.getShiftSalesSummary(activeShift.id!);

    final closedShift = activeShift.copyWith(
      closedAt: DateTime.now(),
      closedBy: userId,
      countedCash: countedCash,
      difference: countedCash - summary.expectedCashBalance,
      notes: notes,
      status: 1, // Yopilgan
    );

    await _repo.updateShift(closedShift);
  }

  /// Smenani qayta ochish (Faqat admin uchun)
  Future<void> reopenShift(int shiftId, String reason, int adminId) async {
    // Admin ekanligini tekshirish lozim (service caller darajasida yoki bu yerda)
    final db = await _dbHelper.database;
    final userRes = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [adminId],
    );
    if (userRes.isEmpty || userRes.first['role'] != 'admin') {
      throw Exception('Smenani qayta ochish uchun faqat admin ruxsatga ega');
    }

    // Smenani yuklash
    final shiftRes = await db.query(
      'shifts',
      where: 'id = ?',
      whereArgs: [shiftId],
    );
    if (shiftRes.isEmpty) throw Exception('Smena topilmadi');

    final shift = Shift.fromMap(shiftRes.first);
    final updatedShift = shift.copyWith(
      status: 0,
      notes:
          (shift.notes ?? '') +
          '\n[Qayta ochildi: $reason (Admin ID: $adminId)]',
    );

    await _repo.updateShift(updatedShift);
  }

  // --- Kassa Harakatlari ---

  /// Kassa harakatini (kirim/chiqim) hozirgi smenaga bog'langan holda qo'shish
  Future<void> addCashMovement({
    required double amount,
    required String type, // 'IN' yoki 'OUT'
    required String reason,
    String? note,
    required int userId,
  }) async {
    final activeShift = await _repo.getOpenShift();
    if (activeShift == null) {
      throw Exception('Kassa harakati uchun ochiq smena bo\'lishi shart');
    }

    final movement = CashMovement(
      shiftId: activeShift.id!,
      type: type,
      amount: amount,
      reason: reason,
      note: note,
      createdAt: DateTime.now(),
      createdBy: userId,
    );

    await _repo.insertCashMovement(movement);
  }

  // --- Xavfsizlik va Tekshiruvlar ---

  /// Sotuv bloklanganmi yoki yo'qligini tekshirish
  /// (Smena ochiq bo'lishi shart degan sozlama bo'lsa tekshiradi)
  Future<bool> isSellingBlocked() async {
    // Kelajakda sozlamalardan (Settings) o'qib olish mumkin
    // Hozircha doimiy ravishda ochiq smena talab qilinishini hisobga olamiz
    final activeShift = await _repo.getOpenShift();
    return activeShift == null;
  }

  /// Hozirgi ochiq smena ID sini olish (Buyurtmalarni bog'lash uchun)
  Future<int?> getActiveShiftId() async {
    final shift = await _repo.getOpenShift();
    return shift?.id;
  }
}
