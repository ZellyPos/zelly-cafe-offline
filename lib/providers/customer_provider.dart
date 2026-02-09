import 'package:flutter/material.dart';
import '../core/database_helper.dart';
import '../models/customer.dart';
import '../models/transaction.dart';

class CustomerProvider extends ChangeNotifier {
  List<Customer> _customers = [];
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  List<Customer> get customers => _customers;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  Future<void> loadCustomers() async {
    _isLoading = true;
    notifyListeners();

    final db = DatabaseHelper.instance;
    final results = await db.queryAll('customers');
    _customers = results.map((e) => Customer.fromMap(e)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCustomer(Customer customer) async {
    final db = DatabaseHelper.instance;
    await db.insert('customers', customer.toMap());
    await loadCustomers();
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = DatabaseHelper.instance;
    await db.update('customers', customer.toMap(), 'id = ?', [customer.id]);
    await loadCustomers();
  }

  Future<void> deleteCustomer(int id) async {
    final db = DatabaseHelper.instance;
    await db.delete('customers', 'id = ?', [id]);
    await loadCustomers();
  }

  Future<void> loadTransactions(int? customerId) async {
    _isLoading = true;
    notifyListeners();

    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'transactions',
      where: customerId != null ? 'customer_id = ?' : null,
      whereArgs: customerId != null ? [customerId] : null,
      orderBy: 'created_at DESC',
    );
    _transactions = results.map((e) => Transaction.fromMap(e)).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
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

    await loadCustomers();
    if (transaction.customerId != null) {
      await loadTransactions(transaction.customerId);
    }
  }
}
