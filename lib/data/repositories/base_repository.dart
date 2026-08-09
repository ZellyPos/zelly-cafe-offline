import '../../core/database_helper.dart';
import '../../providers/connectivity_provider.dart';

/// Barcha repozitoriylar uchun umumiy asos.
///
/// Ma'lumotni ikki manbadan boshqaradi:
///  - **Lokal:** SQLite ([DatabaseHelper]);
///  - **Remote:** lokal tarmoqdagi server ([ConnectivityProvider], `client`
///    rejimida ishlaganda).
///
/// Muhim qoida: **SQL faqat shu (data) qatlamda bo'ladi.** Provider va ekranlar
/// bevosita [DatabaseHelper]ga murojaat qilmasligi kerak — ular repozitoriyni
/// chaqiradi.
///
/// Oddiy CRUD domenlari (`categories`, `customers`, `locations`, ...) uchun bu
/// asosning o'zi yetarli. Maxsus so'rovlar domen repozitoriysida qo'shiladi.
abstract class BaseRepository<T> {
  DatabaseHelper get dbHelper => DatabaseHelper.instance;

  /// SQLite jadval nomi (masalan, `'categories'`).
  String get table;

  /// Remote API yo'li (masalan, `'/categories'`).
  String get remotePath;

  /// `getAll` uchun tartiblash bandi (masalan, `'sort_order ASC'`).
  /// `null` bo'lsa — tartibsiz.
  String? get orderBy => null;

  /// Remote'dan olingan yozuvlar lokal bazaga keshlanadimi (offline uchun)?
  /// Ba'zi domenlar (masalan `products`, `categories`) keshlaydi, ba'zilari
  /// (masalan `customers`) yo'q. Standart — keshlash.
  bool get cacheRemoteToLocal => true;

  T fromMap(Map<String, dynamic> map);

  Map<String, dynamic> toMap(T item);

  /// Yozuvdan `id`ni ajratib olish (o'chirish/yangilash uchun).
  int? idOf(T item);

  /// Remote'dan olingan yozuvni lokalga saqlashdan oldin tozalash hook'i
  /// (masalan, DB ustuni bo'lmagan hosila maydonlarni olib tashlash).
  Map<String, dynamic> sanitizeForLocal(Map<String, dynamic> remoteRow) =>
      remoteRow;

  /// Barcha yozuvlarni oladi.
  ///
  /// `client` rejimida (va `shouldFetchRemote` true bo'lsa) remote'dan oladi va
  /// keyingi offline foydalanish uchun lokal bazaga sinxronlaydi. Aks holda —
  /// to'g'ridan-to'g'ri lokal bazadan o'qiydi.
  Future<List<T>> getAll({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    if (connectivity != null &&
        connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
      final remote = await connectivity.getRemoteData(remotePath);
      final rows = List<Map<String, dynamic>>.from(remote);
      if (cacheRemoteToLocal) await _syncToLocal(rows);
      return rows.map(fromMap).toList();
    }
    final db = await dbHelper.database;
    final rows = await db.query(table, orderBy: orderBy);
    return rows.map(fromMap).toList();
  }

  /// Remote yozuvlarni bitta tranzaksiyada lokal jadvalga to'liq almashtiradi.
  Future<void> _syncToLocal(List<Map<String, dynamic>> rows) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(table);
      for (final row in rows) {
        await txn.insert(table, sanitizeForLocal(Map<String, dynamic>.from(row)));
      }
    });
  }

  /// Yangi yozuv qo'shadi. `client` rejimida remote'ga yuboradi.
  ///
  /// Qaytaradi: `client` rejimida serverdan kelgan muvaffaqiyat holati;
  /// lokal rejimda har doim `true`.
  Future<bool> add(T item, {ConnectivityProvider? connectivity}) async {
    if (_useRemote(connectivity)) {
      return await connectivity!.postRemoteData(remotePath, toMap(item));
    }
    await dbHelper.insert(table, toMap(item));
    return true;
  }

  /// Mavjud yozuvni `id` bo'yicha yangilaydi. `client` rejimida remote'ga yuboradi.
  ///
  /// Qaytaradi: `client` rejimida serverdan kelgan muvaffaqiyat holati;
  /// lokal rejimda har doim `true`.
  Future<bool> update(T item, {ConnectivityProvider? connectivity}) async {
    if (_useRemote(connectivity)) {
      return await connectivity!.postRemoteData(remotePath, toMap(item));
    }
    await dbHelper.update(table, toMap(item), 'id = ?', [idOf(item)]);
    return true;
  }

  /// Yozuvni `id` bo'yicha o'chiradi. `client` rejimida remote'ga yuboradi.
  ///
  /// Qaytaradi: `client` rejimida serverdan kelgan muvaffaqiyat holati;
  /// lokal rejimda har doim `true`.
  Future<bool> deleteById(int id, {ConnectivityProvider? connectivity}) async {
    if (_useRemote(connectivity)) {
      return await connectivity!.deleteRemoteData('$remotePath/$id');
    }
    await dbHelper.delete(table, 'id = ?', [id]);
    return true;
  }

  bool _useRemote(ConnectivityProvider? c) =>
      c != null && c.mode == ConnectivityMode.client;
}
