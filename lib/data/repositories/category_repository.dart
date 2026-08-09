import '../../models/category.dart';
import 'base_repository.dart';

/// Kategoriyalar uchun ma'lumotlar qatlami.
///
/// Barcha CRUD [BaseRepository]dan meros olinadi; kategoriyalar `sort_order`
/// bo'yicha tartiblanadi.
class CategoryRepository extends BaseRepository<Category> {
  @override
  String get table => 'categories';

  @override
  String get remotePath => '/categories';

  @override
  String? get orderBy => 'sort_order ASC';

  @override
  Category fromMap(Map<String, dynamic> map) => Category.fromMap(map);

  @override
  Map<String, dynamic> toMap(Category item) => item.toMap();

  @override
  int? idOf(Category item) => item.id;
}
