import '../../models/location.dart';
import 'base_repository.dart';

/// Joylar (zallar) uchun ma'lumotlar qatlami.
class LocationRepository extends BaseRepository<Location> {
  @override
  String get table => 'locations';

  @override
  String get remotePath => '/locations';

  @override
  Location fromMap(Map<String, dynamic> map) => Location.fromMap(map);

  @override
  Map<String, dynamic> toMap(Location item) => item.toMap();

  @override
  int? idOf(Location item) => item.id;

  /// Berilgan joyga biriktirilgan stollar sonini qaytaradi
  /// (o'chirishdan oldin tekshirish uchun).
  Future<int> countTablesForLocation(int locationId) async {
    final tables = await dbHelper.queryByColumn(
      'tables',
      'location_id',
      locationId,
    );
    return tables.length;
  }
}
