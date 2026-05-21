// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/transaction.dart' as app_transaction;
import 'dart:convert';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Duration _timeout = Duration(seconds: 30);

  // ============================================================
  // PRODUCTS - Now stored under tenants/{tenantId}/products/
  // ============================================================

  // In firestore_service.dart, update the getProducts method:

  Future<List<Product>> getProducts(String tenantId) async {
    try {
      // Query ONLY products for this specific tenant from their subcollection
      final snapshot = await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('products')
          .get()
          .timeout(_timeout);

      if (snapshot.docs.isEmpty) {
        // Check if we've already seeded products for this tenant
        final seedFlag = await _db
            .collection('tenants')
            .doc(tenantId)
            .collection('_metadata')
            .doc('seeded')
            .get();

        // Only seed if not already seeded
        if (!seedFlag.exists || seedFlag.data()?['productsSeeded'] != true) {
          debugPrint('📦 Seeding demo products for tenant: $tenantId');
          final demoProducts = _getDemoProducts(tenantId);
          for (final product in demoProducts) {
            await addProduct(product);
          }

          // Mark as seeded
          await _db
              .collection('tenants')
              .doc(tenantId)
              .collection('_metadata')
              .doc('seeded')
              .set({
            'productsSeeded': true,
            'seededAt': FieldValue.serverTimestamp()
          });

          return demoProducts;
        }
        return [];
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Product(
          id: doc.id,
          tenantId: tenantId,
          meds: data['meds'] ?? '',
          brand: data['brand'] ?? '',
          category: data['category'] ?? '',
          lotNumber: data['lotNumber'] ?? '',
          qty: (data['qty'] ?? 0) as int,
          uom: data['uom'] ?? 'Piece',
          cost: ((data['cost'] ?? 0.0) as num).toDouble(),
          srp: ((data['srp'] ?? 0.0) as num).toDouble(),
          expirationDate: (data['expirationDate'] as Timestamp).toDate(),
          reorderThreshold: (data['reorderThreshold'] ?? 10) as int,
          supplier: data['supplier'] ?? '',
          imageUrl: data['imageUrl'],
        );
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Firestore getProducts failed: $e');
      return [];
    }
  }

  List<Product> _getDemoProducts(String tenantId) {
    final now = DateTime.now();
    return [
      Product(
        id: '${tenantId}_p1_${DateTime.now().millisecondsSinceEpoch}',
        tenantId: tenantId,
        meds: 'Amoxicillin',
        brand: 'Medcor',
        category: 'Antibiotics',
        lotNumber: 'LOT-001',
        qty: 85,
        uom: 'Piece',
        cost: 45.0,
        srp: 85.0,
        expirationDate: DateTime(now.year + 1, now.month, now.day),
        reorderThreshold: 30,
        supplier: 'Medcor Pharma',
      ),
      Product(
        id: '${tenantId}_p2_${DateTime.now().millisecondsSinceEpoch}',
        tenantId: tenantId,
        meds: 'Paracetamol',
        brand: 'RiteMed',
        category: 'Pain Relief',
        lotNumber: 'LOT-002',
        qty: 12,
        uom: 'Piece',
        cost: 32.0,
        srp: 65.0,
        expirationDate: DateTime(now.year, now.month + 1, now.day),
        reorderThreshold: 30,
        supplier: 'RiteMed Corp',
      ),
      Product(
        id: '${tenantId}_p3_${DateTime.now().millisecondsSinceEpoch}',
        tenantId: tenantId,
        meds: 'Ibuprofen',
        brand: 'Advil',
        category: 'Pain Relief',
        lotNumber: 'LOT-003',
        qty: 45,
        uom: 'Piece',
        cost: 28.0,
        srp: 55.0,
        expirationDate: DateTime(now.year + 2, now.month, now.day),
        reorderThreshold: 20,
        supplier: 'Pfizer',
      ),
      Product(
        id: '${tenantId}_p4_${DateTime.now().millisecondsSinceEpoch}',
        tenantId: tenantId,
        meds: 'Vitamin C',
        brand: 'Ascorbic',
        category: 'Vitamins',
        lotNumber: 'LOT-004',
        qty: 89,
        uom: 'Piece',
        cost: 15.0,
        srp: 35.0,
        expirationDate: DateTime(now.year + 1, now.month + 3, now.day),
        reorderThreshold: 50,
        supplier: "Nature's Way",
      ),
    ];
  }

  Future<void> addProduct(Product product) async {
    try {
      final productData = {
        'meds': product.meds,
        'brand': product.brand,
        'category': product.category,
        'lotNumber': product.lotNumber,
        'qty': product.qty,
        'uom': product.uom,
        'cost': product.cost,
        'srp': product.srp,
        'expirationDate': Timestamp.fromDate(product.expirationDate),
        'reorderThreshold': product.reorderThreshold,
        'supplier': product.supplier,
        'imageUrl': product.imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // THIS IS CORRECT - saving to tenants/{tenantId}/products
      await _db
          .collection('tenants')
          .doc(product.tenantId)
          .collection('products')
          .doc(product.id)
          .set(productData)
          .timeout(_timeout);

      debugPrint(
          '✅ Product added to tenants/${product.tenantId}/products: ${product.id}');
    } catch (e) {
      debugPrint('⚠️ Firestore addProduct failed: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      // THIS IS CORRECT - updating from tenants/{tenantId}/products
      await _db
          .collection('tenants')
          .doc(product.tenantId)
          .collection('products')
          .doc(product.id)
          .update({
        'meds': product.meds,
        'brand': product.brand,
        'category': product.category,
        'lotNumber': product.lotNumber,
        'qty': product.qty,
        'uom': product.uom,
        'cost': product.cost,
        'srp': product.srp,
        'expirationDate': Timestamp.fromDate(product.expirationDate),
        'reorderThreshold': product.reorderThreshold,
        'supplier': product.supplier,
        'imageUrl': product.imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);

      debugPrint(
          '✅ Product updated in tenants/${product.tenantId}/products: ${product.id}');
    } catch (e) {
      debugPrint('⚠️ Firestore updateProduct failed: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId, String tenantId) async {
    try {
      // THIS IS CORRECT - deleting from tenants/{tenantId}/products
      await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('products')
          .doc(productId)
          .delete()
          .timeout(_timeout);

      debugPrint(
          '✅ Product deleted from tenants/$tenantId/products: $productId');
    } catch (e) {
      debugPrint('⚠️ Firestore deleteProduct failed: $e');
      rethrow;
    }
  }

  // ============================================================
  // TRANSACTIONS - Under tenants/{tenantId}/transactions/
  // ============================================================

  Future<void> addTransaction(app_transaction.Transaction transaction) async {
    try {
      final transactionData = {
        'productId': transaction.productId,
        'productName': transaction.productName,
        'lotNumber': transaction.lotNumber,
        'type': transaction.type == app_transaction.TransactionType.stockIn
            ? 'in'
            : 'out',
        'qty': transaction.qty,
        'reason': transaction.reason,
        'reference': transaction.reference,
        'staffId': transaction.staffId,
        'staffName': transaction.staffName,
        'timestamp': Timestamp.fromDate(transaction.timestamp),
        'balAfter': transaction.balAfter,
        'productDetails': transaction.productDetails,
      };

      await _db
          .collection('tenants')
          .doc(transaction.tenantId)
          .collection('transactions')
          .doc(transaction.id)
          .set(transactionData)
          .timeout(_timeout);

      debugPrint(
          '✅ Transaction added to tenant ${transaction.tenantId}: ${transaction.id}');
    } catch (e) {
      debugPrint('⚠️ Firestore addTransaction failed: $e');
      rethrow;
    }
  }

  // lib/services/firestore_service.dart

  Future<List<app_transaction.Transaction>> getTransactions(
      String tenantId) async {
    try {
      final snapshot = await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get()
          .timeout(_timeout);

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return app_transaction.Transaction(
          id: doc.id,
          productId: data['productId'] ?? '',
          productName: data['productName'] ?? '',
          lotNumber: data['lotNumber'] ?? '',
          type: data['type'] == 'in'
              ? app_transaction.TransactionType.stockIn
              : app_transaction.TransactionType.stockOut,
          qty: (data['qty'] ?? 0) as int,
          reason: data['reason'] ?? '',
          reference: data['reference'] ?? '',
          staffId: data['staffId'] ?? '',
          staffName: data['staffName'] ?? '',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          balAfter: (data['balAfter'] ?? 0) as int,
          tenantId: tenantId,
          productDetails: data['productDetails'] ?? {},
        );
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Firestore getTransactions failed for $tenantId: $e');
      return []; // Return empty list instead of throwing
    }
  }

  // ============================================================
  // TENANTS
  // ============================================================

  Future<List<Map<String, dynamic>>> getAllTenants() async {
    try {
      final snapshot = await _db.collection('tenants').get().timeout(_timeout);

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        // Don't include 'paid' field - it will be calculated
        return data;
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Firestore getAllTenants failed: $e');
      return _getDemoTenants();
    }
  }

  List<Map<String, dynamic>> _getDemoTenants() {
    return [
      {
        'id': 'davmedical',
        'name': 'Davao Medical Center',
        'address': 'Davao City, Davao del Sur',
        'tier': 'Basic',
        'billing': 4500,
        'paid': false,
        'suspended': false,
        'email': 'admin@davmedical.com'
      },
      {
        'id': 'cebgeneral',
        'name': 'Cebu General Hospital',
        'address': 'Cebu City, Cebu',
        'tier': 'Premium',
        'billing': 12500,
        'paid': false,
        'suspended': false,
        'email': 'admin@cebgeneral.com'
      },
    ];
  }

  Future<void> addTenant(String id, Map<String, dynamic> tenantData) async {
    try {
      await _db.collection('tenants').doc(id).set(tenantData).timeout(_timeout);

      debugPrint('✅ Tenant added to Firestore: $id');
    } catch (e) {
      debugPrint('⚠️ Firestore addTenant failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getTenant(String id) async {
    try {
      final doc =
          await _db.collection('tenants').doc(id).get().timeout(_timeout);
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      debugPrint('⚠️ Firestore getTenant failed: $e');
      return null;
    }
  }

  Future<void> updateTenant(String id, Map<String, dynamic> updates) async {
    try {
      await _db
          .collection('tenants')
          .doc(id)
          .set(updates, SetOptions(merge: true))
          .timeout(_timeout);
      debugPrint('✅ Tenant updated in Firestore: $id');
    } catch (e) {
      debugPrint('⚠️ Firestore updateTenant failed: $e');
    }
  }

  Future<void> deleteTenant(String id) async {
    try {
      await _db.collection('tenants').doc(id).delete().timeout(_timeout);
      debugPrint('✅ Tenant deleted from Firestore: $id');
    } catch (e) {
      debugPrint('⚠️ Firestore deleteTenant failed: $e');
    }
  }

  // ============================================================
  // USERS (Auth Accounts)
  // ============================================================

  Future<List<Map<String, dynamic>>> getAllAuthAccounts() async {
    try {
      final snapshot = await _db.collection('users').get().timeout(_timeout);

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Firestore getAllAuthAccounts failed: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAuthAccount(String email) async {
    final normalized = email.toLowerCase().trim();
    try {
      final userDoc =
          await _db.collection('users').doc(normalized).get().timeout(_timeout);

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          data['id'] = userDoc.id;
        }
        return data;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Firestore getAuthAccount failed: $e');
      return null;
    }
  }

  Future<bool> addAuthAccount(
      String email, Map<String, dynamic> accountData) async {
    final normalized = email.toLowerCase().trim();
    try {
      await _db
          .collection('users')
          .doc(normalized)
          .set(accountData)
          .timeout(_timeout);

      // Also save to tenant's staff subcollection if role is staff
      if ((accountData['role'] as String?) == 'staff' &&
          accountData['tenantId'] != null) {
        try {
          await _db
              .collection('tenants')
              .doc(accountData['tenantId'] as String)
              .collection('staff')
              .doc(normalized)
              .set(accountData)
              .timeout(_timeout);
        } catch (e) {
          debugPrint('⚠️ Failed to save to staff subcollection: $e');
        }
      }

      debugPrint('✅ Auth account added to Firestore: $normalized');
      return true;
    } catch (e) {
      debugPrint('⚠️ Firestore addAuthAccount failed: $e');
      return false;
    }
  }

  Future<bool> updateAuthAccount(
      String email, Map<String, dynamic> accountData) async {
    final normalized = email.toLowerCase().trim();
    try {
      await _db
          .collection('users')
          .doc(normalized)
          .set(accountData)
          .timeout(_timeout);

      if ((accountData['role'] as String?) == 'staff' &&
          accountData['tenantId'] != null) {
        try {
          await _db
              .collection('tenants')
              .doc(accountData['tenantId'] as String)
              .collection('staff')
              .doc(normalized)
              .set(accountData)
              .timeout(_timeout);
        } catch (e) {
          debugPrint('⚠️ Failed to update staff subcollection: $e');
        }
      }

      debugPrint('✅ Auth account updated in Firestore: $normalized');
      return true;
    } catch (e) {
      debugPrint('⚠️ Firestore updateAuthAccount failed: $e');
      return false;
    }
  }

  Future<bool> deleteAuthAccount(String email) async {
    final normalized = email.toLowerCase().trim();
    try {
      final account = await getAuthAccount(normalized);

      await _db.collection('users').doc(normalized).delete().timeout(_timeout);

      if (account != null && account['tenantId'] != null) {
        try {
          await _db
              .collection('tenants')
              .doc(account['tenantId'] as String)
              .collection('staff')
              .doc(normalized)
              .delete()
              .timeout(_timeout);
        } catch (e) {
          debugPrint('⚠️ Failed to delete from staff subcollection: $e');
        }
      }

      debugPrint('✅ Auth account deleted from Firestore: $normalized');
      return true;
    } catch (e) {
      debugPrint('⚠️ Firestore deleteAuthAccount failed: $e');
      return false;
    }
  }

  // ============================================================
  // PAYMENTS
  // ============================================================

  Future<void> addPayment(String tenantId, Map<String, dynamic> payment) async {
    try {
      await _db.collection('payments').add({
        ...payment,
        'tenantId': tenantId,
        'timestamp': Timestamp.fromDate(payment['date'] as DateTime),
      }).timeout(_timeout);

      debugPrint('✅ Payment added to Firestore for tenant: $tenantId');
    } catch (e) {
      debugPrint('⚠️ Firestore addPayment failed: $e');
    }
  }

  // ============================================================
  // AUDIT
  // ============================================================

  Future<void> addTenantAudit(
      String tenantId, Map<String, dynamic> audit) async {
    try {
      await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('audit')
          .add(audit)
          .timeout(_timeout);

      debugPrint('✅ Audit entry added for tenant: $tenantId');
    } catch (e) {
      debugPrint('⚠️ Firestore addTenantAudit failed: $e');
    }
  }
  // lib/services/firestore_service.dart

// Add this method for audit entries with specific ID
  // lib/services/firestore_service.dart

// Add this method
  // lib/services/firestore_service.dart

  Future<void> addTenantAuditWithId(
      String tenantId, String auditId, Map<String, dynamic> audit) async {
    try {
      // Check if audit entry already exists
      final existingDoc = await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('audit')
          .doc(auditId)
          .get()
          .timeout(_timeout);

      if (existingDoc.exists) {
        debugPrint('⚠️ Audit entry already exists, skipping: $auditId');
        return;
      }

      await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('audit')
          .doc(auditId)
          .set(audit)
          .timeout(_timeout);

      debugPrint('✅ Audit entry added for tenant: $tenantId with ID: $auditId');
    } catch (e) {
      debugPrint('⚠️ Firestore addTenantAuditWithId failed: $e');
    }
  }

// Receipt methods
  Future<void> saveReceipt(
    String tenantId, {
    required String receiptId,
    required String receiptUrl,
    required String fileName,
    required Uint8List receiptData,
    required String uploadedBy,
  }) async {
    try {
      await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('receipts')
          .doc(receiptId)
          .set({
        'receiptUrl': receiptUrl,
        'receiptData':
            base64Encode(receiptData), // Now base64Encode is available
        'fileName': fileName,
        'uploadedAt': FieldValue.serverTimestamp(),
        'uploadedBy': uploadedBy,
        'verified': false,
      }).timeout(_timeout);

      debugPrint('✅ Receipt saved for tenant: $tenantId');
    } catch (e) {
      debugPrint('⚠️ Firestore saveReceipt failed: $e');
    }
  }
// lib/services/firestore_service.dart

// Add these methods to FirestoreService class

// Save receipt to Super Admin's collection (for global access)
  Future<void> saveReceiptToSuperAdmin({
    required String tenantId,
    required String tenantName,
    required String receiptId,
    required double amount,
    required String method,
    required String reference,
    required String receiptData,
    required String uploadedBy,
  }) async {
    try {
      // Get super admin ID (you can store this in a config or get from auth)
      const superAdminId = 'superadmin';

      await _db
          .collection('superAdmin')
          .doc(superAdminId)
          .collection('receipts')
          .doc(receiptId)
          .set({
        'receiptId': receiptId,
        'tenantId': tenantId,
        'tenantName': tenantName,
        'amount': amount,
        'method': method,
        'reference': reference,
        'receiptData': receiptData,
        'createdAt': FieldValue.serverTimestamp(),
        'uploadedBy': uploadedBy,
        'verified': false,
        'verifiedAt': null,
        'verifiedBy': null,
      }).timeout(_timeout);

      debugPrint(
          '✅ Receipt saved to Super Admin collection for tenant: $tenantId');
    } catch (e) {
      debugPrint('⚠️ Firestore saveReceiptToSuperAdmin failed: $e');
    }
  }

// Get all receipts for Super Admin (across all tenants)
  Future<List<Map<String, dynamic>>> getAllReceiptsForSuperAdmin() async {
    try {
      const superAdminId = 'superadmin';

      final snapshot = await _db
          .collection('superAdmin')
          .doc(superAdminId)
          .collection('receipts')
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(_timeout);

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Firestore getAllReceiptsForSuperAdmin failed: $e');
      return [];
    }
  }

// Verify a receipt (Super Admin action)
  Future<void> verifyReceipt(String receiptId, String verifiedBy) async {
    try {
      const superAdminId = 'superadmin';

      await _db
          .collection('superAdmin')
          .doc(superAdminId)
          .collection('receipts')
          .doc(receiptId)
          .update({
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': verifiedBy,
      }).timeout(_timeout);

      debugPrint('✅ Receipt verified: $receiptId');
    } catch (e) {
      debugPrint('⚠️ Firestore verifyReceipt failed: $e');
    }
  }

// Get receipts by tenant for Super Admin
  Future<List<Map<String, dynamic>>> getReceiptsForTenantBySuperAdmin(
      String tenantId) async {
    try {
      const superAdminId = 'superadmin';

      final snapshot = await _db
          .collection('superAdmin')
          .doc(superAdminId)
          .collection('receipts')
          .where('tenantId', isEqualTo: tenantId)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(_timeout);

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Firestore getReceiptsForTenantBySuperAdmin failed: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getReceipt(
      String tenantId, String receiptId) async {
    try {
      final doc = await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('receipts')
          .doc(receiptId)
          .get()
          .timeout(_timeout);

      return doc.exists ? doc.data() : null;
    } catch (e) {
      debugPrint('⚠️ Firestore getReceipt failed: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTenantReceipts(String tenantId) async {
    try {
      final snapshot = await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('receipts')
          .orderBy('uploadedAt', descending: true)
          .get()
          .timeout(_timeout);

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Firestore getTenantReceipts failed: $e');
      return [];
    }
  }

  // lib/services/firestore_service.dart

// Alert methods (add inside FirestoreService class)

  Future<void> createAlert(
    String tenantId, {
    required String type,
    required String message,
    required String severity,
    required bool actionRequired,
  }) async {
    try {
      final alertId = DateTime.now().millisecondsSinceEpoch.toString();

      await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('alerts')
          .doc(alertId)
          .set({
        'type': type, // 'low_stock', 'expiring', 'payment_due'
        'message': message,
        'severity': severity, // 'info', 'warning', 'critical'
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'readBy': [],
        'actionRequired': actionRequired,
      }).timeout(_timeout);

      debugPrint('✅ Alert created for tenant: $tenantId');
    } catch (e) {
      debugPrint('⚠️ Firestore createAlert failed: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUnreadAlerts(String tenantId) async {
    try {
      final snapshot = await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('alerts')
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get()
          .timeout(_timeout);

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Firestore getUnreadAlerts failed: $e');
      return [];
    }
  }

  Future<void> markAlertAsRead(
      String tenantId, String alertId, String userId) async {
    try {
      await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('alerts')
          .doc(alertId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
        'readBy': FieldValue.arrayUnion([userId]),
      }).timeout(_timeout);

      debugPrint('✅ Alert marked as read: $alertId');
    } catch (e) {
      debugPrint('⚠️ Firestore markAlertAsRead failed: $e');
    }
  }

  Future<void> createLowStockAlert(String tenantId, String productName,
      int currentStock, int threshold) async {
    await createAlert(
      tenantId,
      type: 'low_stock',
      message:
          '⚠️ Low stock alert: $productName has only $currentStock units left (threshold: $threshold)',
      severity: 'warning',
      actionRequired: true,
    );
  }

  Future<void> createExpiryAlert(String tenantId, String productName,
      String lotNumber, int daysLeft) async {
    String severity =
        daysLeft <= 7 ? 'critical' : (daysLeft <= 30 ? 'warning' : 'info');

    await createAlert(
      tenantId,
      type: 'expiring',
      message:
          '📅 Expiry alert: $productName (Lot: $lotNumber) expires in $daysLeft days',
      severity: severity,
      actionRequired: daysLeft <= 7,
    );
  }

  Future<void> createPaymentDueAlert(
      String tenantId, double amount, int daysOverdue) async {
    await createAlert(
      tenantId,
      type: 'payment_due',
      message:
          '💰 Payment due: ₱${amount.toStringAsFixed(2)} is ${daysOverdue > 0 ? '$daysOverdue days overdue' : 'due soon'}',
      severity: daysOverdue > 0 ? 'critical' : 'warning',
      actionRequired: true,
    );
  }

  Future<List<Map<String, dynamic>>> getTenantAuditEntries(
      String tenantId) async {
    try {
      final snapshot = await _db
          .collection('tenants')
          .doc(tenantId)
          .collection('audit')
          .orderBy('timestamp', descending: true)
          .get()
          .timeout(_timeout);
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Firestore getTenantAuditEntries failed: $e');
      return [];
    }
  }
}
