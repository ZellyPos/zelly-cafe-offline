import '../../models/customer.dart';
import '../../models/transaction.dart';
import '../../providers/connectivity_provider.dart';
import 'base_repository.dart';

/// Mijozlar va ular bilan bog'liq tranzaksiyalar uchun ma'lumotlar qatlami.
///
/// Eslatma: mijozlar remote'dan olinganda lokal bazaga keshlanmaydi
/// ([cacheRemoteToLocal] = false) — mavjud xatti-harakat saqlanadi.
class CustomerRepository extends BaseRepository<Customer> {
  @override
  String get table => 'customers';

  @override
  String get remotePath => '/customers';

  @override
  bool get cacheRemoteToLocal => false;

  @override
  Customer fromMap(Map<String, dynamic> map) => Customer.fromMap(map);

  @override
  Map<String, dynamic> toMap(Customer item) => item.toMap();

  @override
  int? idOf(Customer item) => item.id;

  // --- Tranzaksiyalar ---

  /// Mijoz tranzaksiyalari (`customerId` null bo'lsa — barchasi), eng yangi
  /// birinchi.
  Future<List<Transaction>> getTransactions(
    int? customerId, {
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    final List<Map<String, dynamic>> data;
    if (connectivity != null &&
        connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
      final remoteData = await connectivity.getRemoteData(
        '/transactions${customerId != null ? '?customer_id=$customerId' : ''}',
      );
      data = List<Map<String, dynamic>>.from(remoteData);
    } else {
      final db = await dbHelper.database;
      data = await db.query(
        'transactions',
        where: customerId != null ? 'customer_id = ?' : null,
        whereArgs: customerId != null ? [customerId] : null,
        orderBy: 'created_at DESC',
      );
    }
    return data.map((e) => Transaction.fromMap(e)).toList();
  }

  /// Tranzaksiya qo'shadi va (lokal rejimda) mijoz balansini yangilaydi.
  ///
  /// `outlay` — mijozga berilgan pul (qarzini oshiradi);
  /// `payment` — mijoz to'lovi (qarzini kamaytiradi, ortiqchasi kreditga o'tadi).
  Future<void> addTransaction(
    Transaction transaction, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/transactions', transaction.toMap());
      return;
    }

    final db = await dbHelper.database;
    await db.transaction((txn) async {
      // 1. Tranzaksiyani saqlash
      await txn.insert('transactions', transaction.toMap());

      // 2. Bog'langan mijoz balansini yangilash
      if (transaction.customerId != null) {
        final customerRes = await txn.query(
          'customers',
          where: 'id = ?',
          whereArgs: [transaction.customerId],
          limit: 1,
        );

        if (customerRes.isNotEmpty) {
          final customer = Customer.fromMap(customerRes.first);
          double newDebt = customer.debt;
          double newCredit = customer.credit;

          if (transaction.type == 'outlay') {
            // Mijozga berilgan pul — qarzni oshiradi
            newDebt += transaction.amount;
          } else if (transaction.type == 'payment') {
            // Mijoz to'ladi — qarzni kamaytiradi yoki kreditni oshiradi
            if (newDebt >= transaction.amount) {
              newDebt -= transaction.amount;
            } else {
              double remainder = transaction.amount - newDebt;
              newDebt = 0;
              newCredit += remainder;
            }
          }

          await txn.update(
            'customers',
            {'debt': newDebt, 'credit': newCredit},
            where: 'id = ?',
            whereArgs: [transaction.customerId],
          );
        }
      }
    });
  }
}
