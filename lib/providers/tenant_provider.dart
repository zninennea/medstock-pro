// lib/providers/tenant_provider.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/tenant.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/user.dart';

// lib/providers/tenant_provider.dart

class TenantProvider extends ChangeNotifier {
  final Map<String, Tenant> _tenants = {};
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  TenantProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await refreshTenants();
  }

  Map<String, Tenant> get tenants => _tenants;
  Tenant? getCurrentTenant(String id) => _tenants[id];

  // lib/providers/tenant_provider.dart

  Future<void> refreshTenants() async {
    _isLoading = true;
    notifyListeners();

    try {
      final remoteTenants = await _firestoreService.getAllTenants();

      if (remoteTenants.isNotEmpty) {
        _tenants.clear();

        for (final tenantData in remoteTenants) {
          final tenantId = tenantData['id'];
          final tenant = Tenant.fromJson(tenantData);

          // Try to load transactions, but don't fail if permission denied
          try {
            final transactions =
                await _firestoreService.getTransactions(tenantId);
            tenant.transactions = transactions;
          } catch (e) {
            debugPrint('⚠️ Could not load transactions for $tenantId: $e');
            tenant.transactions = [];
          }

          // Try to load products
          try {
            final products = await _firestoreService.getProducts(tenantId);
            tenant.products = products;
          } catch (e) {
            debugPrint('⚠️ Could not load products for $tenantId: $e');
            tenant.products = [];
          }

          _tenants[tenantId] = tenant;
        }

        debugPrint('✅ Loaded ${_tenants.length} tenants with their data');
      }
    } catch (e) {
      debugPrint('⚠️ Error refreshing tenants: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update addTransaction to also update local state
  Future<void> addTransaction(String tenantId, Transaction transaction) async {
    debugPrint('📝 Adding transaction to tenant: $tenantId');

    // Update local state
    if (_tenants.containsKey(tenantId)) {
      _tenants[tenantId]!.transactions.insert(0, transaction);
      debugPrint('✅ Transaction added to local state: ${transaction.id}');

      // Update product stock locally
      final productIndex = _tenants[tenantId]!
          .products
          .indexWhere((p) => p.id == transaction.productId);

      if (productIndex != -1) {
        final product = _tenants[tenantId]!.products[productIndex];
        if (transaction.type == TransactionType.stockIn) {
          product.qty += transaction.qty;
        } else {
          product.qty -= transaction.qty;
        }
        _tenants[tenantId]!.products[productIndex] = product;
        debugPrint(
            '✅ Product stock updated locally: ${product.meds} -> ${product.qty}');
      }

      notifyListeners();
    }

    // Save to Firestore
    try {
      await _firestoreService.addTransaction(transaction);
      debugPrint('✅ Transaction saved to Firestore: ${transaction.id}');
    } catch (e) {
      debugPrint('⚠️ Failed to save transaction to Firestore: $e');
    }
  }

  // lib/providers/tenant_provider.dart

  Future<void> addAuditEntryWithId(
      String tenantId, String auditId, AuditEntry entry) async {
    debugPrint('📝 Adding audit entry to tenant: $tenantId');
    debugPrint('   Action: ${entry.action}');
    debugPrint('   Details: ${entry.details}');

    // Update local state
    if (_tenants.containsKey(tenantId)) {
      _tenants[tenantId]!.auditTrail.insert(0, entry);
      notifyListeners();
    }

    // Save to Firestore
    try {
      await _firestoreService.addTenantAuditWithId(tenantId, auditId, {
        'timestamp': entry.timestamp.toIso8601String(),
        'action': entry.action,
        'details': entry.details,
        'user': entry.user,
        'role': entry.role.name,
      });
      debugPrint('✅ Audit entry saved to Firestore: $auditId');
    } catch (e) {
      debugPrint('⚠️ Failed to save audit entry to Firestore: $e');
    }
  }

  // Update addProduct
  void addProduct(String tenantId, Product product) {
    if (_tenants.containsKey(tenantId)) {
      _tenants[tenantId]!.products.add(product);
      notifyListeners();
    }
  }

  // Update updateProduct
  void updateProduct(String tenantId, Product product) {
    if (_tenants.containsKey(tenantId)) {
      final index =
          _tenants[tenantId]!.products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _tenants[tenantId]!.products[index] = product;
        notifyListeners();
      }
    }
  }

  // Update deleteProduct
  void deleteProduct(String tenantId, String productId) {
    if (_tenants.containsKey(tenantId)) {
      _tenants[tenantId]!.products.removeWhere((p) => p.id == productId);
      notifyListeners();
    }
  }

  // Keep your existing methods...
  void syncProducts(String tenantId, List<Product> products) {
    final tenant = _tenants[tenantId];
    if (tenant != null) {
      tenant.products = List<Product>.from(products);
      notifyListeners();
    }
  }

  Future<void> addAuditEntry(String tenantId, AuditEntry entry) async {
    if (_tenants.containsKey(tenantId)) {
      _tenants[tenantId]!.auditTrail.insert(0, entry);
      notifyListeners();
    }

    await _firestoreService.addTenantAudit(tenantId, {
      'timestamp': entry.timestamp.toIso8601String(),
      'action': entry.action,
      'details': entry.details,
      'user': entry.user,
      'role': entry.role.name,
    });
  }

  List<Product> getFilteredProducts(
    String tenantId, {
    String? search,
    String? category,
    String? sortBy,
  }) {
    final tenant = _tenants[tenantId];
    if (tenant == null) return [];

    var products = List<Product>.from(tenant.products);

    if (search != null && search.isNotEmpty) {
      products = products
          .where((p) =>
              p.meds.toLowerCase().contains(search.toLowerCase()) ||
              p.brand.toLowerCase().contains(search.toLowerCase()) ||
              p.lotNumber.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }

    if (category != null && category.isNotEmpty) {
      products = products.where((p) => p.category == category).toList();
    }

    switch (sortBy) {
      case 'az':
        products.sort((a, b) => a.meds.compareTo(b.meds));
        break;
      case 'za':
        products.sort((a, b) => b.meds.compareTo(a.meds));
        break;
      case 'qty-low':
        products.sort((a, b) => a.qty.compareTo(b.qty));
        break;
      case 'qty-high':
        products.sort((a, b) => b.qty.compareTo(a.qty));
        break;
      case 'expiry':
        products.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
        break;
    }

    return products;
  }

  Future<void> addPayment(String tenantId, PaymentRecord payment) async {
    final tenant = _tenants[tenantId];
    if (tenant == null) return;

    tenant.paymentHistory.insert(0, payment);
    tenant.paid = true;
    tenant.suspended = false;
    notifyListeners();

    await _firestoreService.addPayment(tenantId, {
      'date': payment.date,
      'amount': payment.amount,
      'receiptUrl': payment.receiptUrl,
      'method': payment.method,
      'period': payment.period,
      'reference': payment.reference,
      'isVerified': payment.isVerified,
    });
  }

  void verifyPayment(String reference) {
    for (final tenant in _tenants.values) {
      final index =
          tenant.paymentHistory.indexWhere((p) => p.reference == reference);
      if (index != -1) {
        tenant.paymentHistory[index].isVerified = true;
        notifyListeners();
        break;
      }
    }
  }

  Future<void> registerTenant({
    required String id,
    required String name,
    required String address,
    required TenantTier tier,
    required double billing,
    required String email,
  }) async {
    _tenants[id] = Tenant(
      id: id,
      name: name,
      address: address,
      tier: tier,
      billing: billing,
      email: email,
      paid: false,
      suspended: false,
      products: [],
      transactions: [],
      auditTrail: [
        AuditEntry(
          timestamp: DateTime.now(),
          action: 'Tenant Registered',
          details: 'Tenant account created under $tier plan',
          user: 'Super Admin',
          role: UserRole.superAdmin,
        )
      ],
      paymentHistory: [],
      settings: TenantSettings(),
    );

    await _firestoreService.addTenant(id, {
      'name': name,
      'address': address,
      'tier': tier == TenantTier.basic ? 'Basic' : 'Premium',
      'billing': billing,
      'email': email,
      'paid': false,
      'suspended': false,
    });

    notifyListeners();
  }
}
