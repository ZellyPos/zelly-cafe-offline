import 'package:flutter/material.dart';
import '../data/repositories/customer_repository.dart';
import '../models/customer.dart';
import '../models/transaction.dart';
import 'connectivity_provider.dart';

class CustomerProvider extends ChangeNotifier {
  final CustomerRepository _repo;

  CustomerProvider({CustomerRepository? repository})
    : _repo = repository ?? CustomerRepository();

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
      _customers = await _repo.getAll(
        connectivity: connectivity,
        forceRemote: forceRemote,
      );
    } catch (e) {
      debugPrint('Error loading customers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCustomer(
    Customer customer, {
    ConnectivityProvider? connectivity,
  }) async {
    await _repo.add(customer, connectivity: connectivity);
    await loadCustomers(connectivity: connectivity);
  }

  Future<void> updateCustomer(
    Customer customer, {
    ConnectivityProvider? connectivity,
  }) async {
    await _repo.update(customer, connectivity: connectivity);
    await loadCustomers(connectivity: connectivity);
  }

  Future<void> deleteCustomer(
    int id, {
    ConnectivityProvider? connectivity,
  }) async {
    await _repo.deleteById(id, connectivity: connectivity);
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
      _transactions = await _repo.getTransactions(
        customerId,
        connectivity: connectivity,
        forceRemote: forceRemote,
      );
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(
    Transaction transaction, {
    ConnectivityProvider? connectivity,
  }) async {
    await _repo.addTransaction(transaction, connectivity: connectivity);

    await loadCustomers(connectivity: connectivity);
    if (transaction.customerId != null) {
      await loadTransactions(
        transaction.customerId,
        connectivity: connectivity,
      );
    }
  }
}
