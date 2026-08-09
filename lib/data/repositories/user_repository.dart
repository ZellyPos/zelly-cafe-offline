import '../../models/user.dart';
import 'base_repository.dart';

/// Foydalanuvchilar (admin/kassir) uchun ma'lumotlar qatlami.
///
/// Remote'dan olinganda lokalga keshlanmaydi ([cacheRemoteToLocal] = false).
class UserRepository extends BaseRepository<AppUser> {
  @override
  String get table => 'users';

  @override
  String get remotePath => '/users';

  @override
  bool get cacheRemoteToLocal => false;

  @override
  AppUser fromMap(Map<String, dynamic> map) => AppUser.fromMap(map);

  @override
  Map<String, dynamic> toMap(AppUser item) => item.toMap();

  @override
  int? idOf(AppUser item) => item.id;

  /// Foydalanuvchi rolini `id` bo'yicha qaytaradi (masalan admin'ni o'chirishdan
  /// himoyalash uchun).
  Future<String?> getRoleById(int id) async {
    final res = await dbHelper.queryByColumn('users', 'id', id);
    if (res.isEmpty) return null;
    return res.first['role'] as String?;
  }

  /// PIN bo'yicha foydalanuvchini qaytaradi (login uchun); topilmasa `null`.
  Future<Map<String, dynamic>?> getUserByPin(String pin) async {
    final res = await dbHelper.queryByColumn('users', 'pin', pin);
    return res.isNotEmpty ? res.first : null;
  }
}
