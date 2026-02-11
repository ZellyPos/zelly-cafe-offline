import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import 'connectivity_provider.dart';

class CustomerProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  Future<void> loadCustomers({
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data;
      if (connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
        final remoteData = await connectivity.getRemoteData('/customers');
        data = List<Map<String, dynamic>>.from(remoteData);
      } else {
        data = await DatabaseHelper.instance.queryAll('customers');
      }
      _customers = data.map((e) => Customer.fromMap(e)).toList();
    } catch (e) {
      debugPrint("Error loading customers: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCustomer(
    Customer customer, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/customers', customer.toMap());
    } else {
      await DatabaseHelper.instance.insert('customers', customer.toMap());
    }
    await loadCustomers(connectivity: connectivity);
  }

  Future<void> updateCustomer(
    Customer customer, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/customers', customer.toMap());
    } else {
      await DatabaseHelper.instance.update(
        'customers',
        customer.toMap(),
        'id = ?',
        [customer.id],
      );
    }
    await loadCustomers(connectivity: connectivity);
  }

  Future<void> deleteCustomer(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.deleteRemoteData('/customers/$id');
    } else {
      await DatabaseHelper.instance.delete('customers', 'id = ?', [id]);
    }
    await loadCustomers(connectivity: connectivity);
  }

  Future<void> loadTransactions(
    int? customerId, {
    ConnectivityProvider? connectivity,
    bool forceRemote = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final List<Map<String, dynamic>> data;
      if (connectivity != null &&
          connectivity.shouldFetchRemote(forceRemote: forceRemote)) {
        final remoteData = await connectivity.getRemoteData(
          '/transactions${customerId != null ? '?customer_id=$customerId' : ''}',
        );
        data = List<Map<String, dynamic>>.from(remoteData);
      } else {
        final db = await DatabaseHelper.instance.database;
        data = await db.query(
          'transactions',
          where: customerId != null ? 'customer_id = ?' : null,
          whereArgs: customerId != null ? [customerId] : null,
          orderBy: 'created_at DESC',
        );
      }
      _transactions = data.map((e) => Transaction.fromMap(e)).toList();
    } catch (e) {
      debugPrint("Error loading transactions: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(
    Transaction transaction, {
    ConnectivityProvider? connectivity,
  }) async {
    if (connectivity != null && connectivity.mode == ConnectivityMode.client) {
      await connectivity.postRemoteData('/transactions', transaction.toMap());
    } else {
      final db = (await DatabaseHelper.instance.database);

      await db.transaction((txn) async {
        // 1. Insert transaction
        await txn.insert('transactions', transaction.toMap());

        // 2. Update customer balance if linked
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
              // Money given to customer (outlay increases their debt)
              newDebt += transaction.amount;
            } else if (transaction.type == 'payment') {
              // Customer paid us (payment decreases their debt or increases credit)
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

    await loadCustomers(connectivity: connectivity);
    if (transaction.customerId != null) {
      await loadTransactions(
        transaction.customerId,
        connectivity: connectivity,
      );
    }
  }
}
