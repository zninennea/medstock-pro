// lib/providers/tenant_provider.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/tenant.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/user.dart';

class TenantProvider extends ChangeNotifier {
  final Map<String, Tenant> _tenants = {};
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, Tenant> get tenants => _tenants;
  Tenant? getCurrentTenant(String id) => _tenants[id];

  TenantProvider() {
    _initializeDemoData();
    _seedTenantDemoData();
    _refreshTenants();
  }

  Future<void> _refreshTenants() async {
    await refreshTenants();
  }

  Future<void> refreshTenants() async {
    try {
      final remoteTenants = await _firestoreService.getAllTenants();
      if (remoteTenants.isNotEmpty) {
        _tenants.clear();
        for (final tenantData in remoteTenants) {
          final tenant = Tenant.fromJson(tenantData);
          _tenants[tenant.id] = tenant;
        }
        notifyListeners();
      }
    } catch (_) {
      // Keep demo data if Firestore is unavailable.
    }
  }

  void _initializeDemoData() {
    final now = DateTime.now();

    List<Product> getDemoProducts(String tenantId) {
      return [
        Product(
          id: 'p1',
          tenantId: tenantId,
          meds: 'Amoxicillin',
          brand: 'Medcor',
          category: 'Antibiotics',
          lotNumber: 'LOT-001',
          qty: 85,
          uom: 'Piece',
          cost: 45.0,
          srp: 85.0,
          expirationDate: now.add(const Duration(days: 20)),
          reorderThreshold: 30,
          supplier: 'Medcor Pharma',
        ),
        Product(
          id: 'p2',
          tenantId: tenantId,
          meds: 'Paracetamol',
          brand: 'RiteMed',
          category: 'Pain Relief',
          lotNumber: 'LOT-002',
          qty: 12,
          uom: 'Piece',
          cost: 32.0,
          srp: 65.0,
          expirationDate: now.add(const Duration(days: 15)),
          reorderThreshold: 30,
          supplier: 'RiteMed Corp',
        ),
        Product(
          id: 'p3',
          tenantId: tenantId,
          meds: 'Ibuprofen',
          brand: 'Advil',
          category: 'Pain Relief',
          lotNumber: 'LOT-003',
          qty: 45,
          uom: 'Piece',
          cost: 28.0,
          srp: 55.0,
          expirationDate: now.add(const Duration(days: 120)),
          reorderThreshold: 20,
          supplier: 'Pfizer',
        ),
        Product(
          id: 'p4',
          tenantId: tenantId,
          meds: 'Vitamin C',
          brand: 'Ascorbic',
          category: 'Vitamins',
          lotNumber: 'LOT-004',
          qty: 89,
          uom: 'Piece',
          cost: 15.0,
          srp: 35.0,
          expirationDate: now.add(const Duration(days: 300)),
          reorderThreshold: 50,
          supplier: "Nature's Way",
        ),
      ];
    }

    List<Transaction> getDemoTransactions(String tenantId) {
      return [
        Transaction(
          id: 't1',
          productId: 'p1',
          productName: 'Amoxicillin',
          lotNumber: 'LOT-001',
          type: TransactionType.stockIn,
          qty: 50,
          reason: 'Restock (Purchase)',
          reference: 'TX-IN-12345',
          staffId: 'staff1',
          staffName: 'Maria Santos',
          timestamp: now.subtract(const Duration(days: 2)),
          balAfter: 85,
          tenantId: tenantId,
          productDetails: {},
        ),
        Transaction(
          id: 't2',
          productId: 'p2',
          productName: 'Paracetamol',
          lotNumber: 'LOT-002',
          type: TransactionType.stockOut,
          qty: 10,
          reason: 'Dispensed to Patient',
          reference: 'TX-OUT-67890',
          staffId: 'staff1',
          staffName: 'Maria Santos',
          timestamp: now.subtract(const Duration(days: 3)),
          balAfter: 12,
          tenantId: tenantId,
          productDetails: {},
        ),
        Transaction(
          id: 't3',
          productId: 'p3',
          productName: 'Ibuprofen',
          lotNumber: 'LOT-003',
          type: TransactionType.stockIn,
          qty: 30,
          reason: 'Restock (Purchase)',
          reference: 'TX-IN-11223',
          staffId: 'staff1',
          staffName: 'Maria Santos',
          timestamp: now.subtract(const Duration(days: 10)),
          balAfter: 45,
          tenantId: tenantId,
          productDetails: {},
        ),
      ];
    }

    final emptyAuditTrail = <AuditEntry>[
      AuditEntry(
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        action: 'Stock Out',
        details:
            'Dispensed 10 units of Paracetamol (LOT-002) - Dispensed to Patient',
        user: 'Maria Santos',
        role: UserRole.staff,
      ),
      AuditEntry(
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        action: 'Stock In',
        details:
            'Restocked 50 units of Amoxicillin (LOT-001) - Restock (Purchase)',
        user: 'Maria Santos',
        role: UserRole.staff,
      ),
      AuditEntry(
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        action: 'Product Added',
        details: 'Added product Vitamin C (LOT-004)',
        user: 'Dr. Cruz',
        role: UserRole.admin,
      ),
    ];

    _tenants['davmedical'] = Tenant(
      id: 'davmedical',
      name: 'Davao Medical Center',
      address: 'Davao City, Davao del Sur',
      tier: TenantTier.basic,
      billing: 4500,
      email: 'admin@davmedical.com',
      paid: false,
      suspended: false,
      products: getDemoProducts('davmedical'),
      transactions: getDemoTransactions('davmedical'),
      auditTrail: emptyAuditTrail,
      paymentHistory: [
        PaymentRecord(
          date: DateTime.now().subtract(const Duration(days: 10)),
          amount: 4500,
          receiptUrl: 'https://picsum.photos/id/20/300/400',
          method: 'GCash',
          period: DateTime.now(),
          reference: 'INV-1714902800123',
          isVerified: true,
        ),
      ],
      settings: TenantSettings(),
    );

    _tenants['cebgeneral'] = Tenant(
      id: 'cebgeneral',
      name: 'Cebu General Hospital',
      address: 'Cebu City, Cebu',
      tier: TenantTier.premium,
      billing: 12500,
      email: 'admin@cebgeneral.com',
      paid: false,
      suspended: false,
      products: getDemoProducts('cebgeneral'),
      transactions: getDemoTransactions('cebgeneral'),
      auditTrail: emptyAuditTrail
          .map((e) => AuditEntry(
                timestamp: e.timestamp,
                action: e.action,
                details: e.details,
                user: 'Assistant',
                role: UserRole.staff,
              ))
          .toList(),
      paymentHistory: [
        PaymentRecord(
          date: DateTime.now().subtract(const Duration(days: 15)),
          amount: 12500,
          receiptUrl: 'https://picsum.photos/id/20/300/400',
          method: 'Cash',
          period: DateTime.now(),
          reference: 'INV-1714802800456',
          isVerified: true,
        ),
      ],
      settings: TenantSettings(emailAlerts: true),
    );
  }

  Future<void> _seedTenantDemoData() async {
    try {
      await _firestoreService.getAllTenants();
    } catch (_) {
      // Ignore Firestore issues while seeding demo tenant documents.
    }
  }

  void syncProducts(String tenantId, List<Product> products) {
    final tenant = _tenants[tenantId];
    if (tenant != null) {
      tenant.products = List<Product>.from(products);
      notifyListeners();
    }
  }

  // In tenant_provider.dart, update the addAuditEntry method:

  Future<void> addAuditEntry(String tenantId, AuditEntry entry) async {
    // Update local state
    if (_tenants.containsKey(tenantId)) {
      _tenants[tenantId]!.auditTrail.insert(0, entry);
      notifyListeners();
    }

    // Save to Firestore
    try {
      await _firestoreService.addTenantAudit(tenantId, {
        'timestamp': entry.timestamp.toIso8601String(),
        'action': entry.action,
        'details': entry.details,
        'user': entry.user,
        'role': entry.role.name,
      });
      debugPrint('✅ Audit entry saved to Firestore for tenant: $tenantId');
    } catch (e) {
      debugPrint('⚠️ Failed to save audit entry to Firestore: $e');
    }
  }

  void addProduct(String tenantId, Product product) {
    _tenants[tenantId]?.products.add(product);
    notifyListeners();
  }

  void updateProduct(String tenantId, Product product) {
    final index =
        _tenants[tenantId]?.products.indexWhere((p) => p.id == product.id);
    if (index != null && index != -1) {
      _tenants[tenantId]?.products[index] = product;
      notifyListeners();
    }
  }

  void deleteProduct(String tenantId, String productId) {
    _tenants[tenantId]?.products.removeWhere((p) => p.id == productId);
    notifyListeners();
  }

// lib/providers/tenant_provider.dart

// Fix addTransaction - remove the problematic closure
  Future<void> addTransaction(String tenantId, Transaction transaction) async {
    // Check if transaction already exists locally
    if (_tenants.containsKey(tenantId)) {
      bool exists = false;
      for (final t in _tenants[tenantId]!.transactions) {
        if (t.id == transaction.id) {
          exists = true;
          break;
        }
      }

      if (exists) {
        debugPrint('⚠️ Transaction already exists locally: ${transaction.id}');
        return;
      }

      _tenants[tenantId]!.transactions.insert(0, transaction);

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

// Fix addAuditEntryWithId
  Future<void> addAuditEntryWithId(
      String tenantId, String auditId, AuditEntry entry) async {
    // Check if audit entry already exists locally
    if (_tenants.containsKey(tenantId)) {
      bool exists = false;
      for (final a in _tenants[tenantId]!.auditTrail) {
        if (a.timestamp == entry.timestamp && a.details == entry.details) {
          exists = true;
          break;
        }
      }

      if (exists) {
        debugPrint('⚠️ Audit entry already exists locally, skipping');
        return;
      }

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
  // In tenant_provider.dart, update the addPayment method:

  Future<void> addPayment(String tenantId, PaymentRecord payment) async {
    final tenant = _tenants[tenantId];
    if (tenant == null) return;

    // Update local state
    tenant.paymentHistory.insert(0, payment);
    tenant.paid = true;
    tenant.suspended = false;
    notifyListeners();

    // Save to Firestore - payments collection
    try {
      await _firestoreService.addPayment(tenantId, {
        'date': payment.date,
        'amount': payment.amount,
        'receiptUrl': payment.receiptUrl,
        'method': payment.method,
        'period': payment.period,
        'reference': payment.reference,
        'isVerified': payment.isVerified,
      });
      debugPrint('✅ Payment saved to Firestore for tenant: $tenantId');
    } catch (e) {
      debugPrint('⚠️ Failed to save payment to Firestore: $e');
    }

    // ALSO update the tenant document to mark as paid
    try {
      await _firestoreService.updateTenant(tenantId, {
        'paid': true,
        'suspended': false,
        'lastPaymentDate': payment.date,
      });
      debugPrint('✅ Tenant $tenantId marked as paid in Firestore');
    } catch (e) {
      debugPrint('⚠️ Failed to update tenant paid status: $e');
    }
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

    // Live sync to Firestore
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
