// lib/providers/product_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';

class ProductProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadProducts(String tenantId) async {
    debugPrint('🔄 Loading products for tenant: $tenantId');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _products = await _firestoreService.getProducts(tenantId);
      debugPrint('✅ Loaded ${_products.length} products');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading products: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      debugPrint('📦 Adding product to tenant: ${product.tenantId}');
      await _firestoreService.addProduct(product);

      _products.add(product);
      notifyListeners();

      // Check and create alerts for new product
      await _checkAndCreateAlerts(product);

      await _resolveAlertsForProduct(product);

      debugPrint('✅ Product added successfully: ${product.id}');
    } catch (e) {
      debugPrint('❌ Error adding product: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      debugPrint(
          '📝 Updating product: ${product.id} in tenant: ${product.tenantId}');

      // Get old product to compare stock changes
      final oldProduct = _products.firstWhere((p) => p.id == product.id);

      await _firestoreService.updateProduct(product);

      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }

      // Check and create alerts after update
      await _checkAndCreateAlerts(product);

      // ADD THIS LINE - Auto-resolve alerts when stock is replenished
      await _resolveAlertsForProduct(product);

      // Also check if stock crossed below threshold
      if (oldProduct.qty > product.reorderThreshold &&
          product.qty <= product.reorderThreshold) {
        await _createLowStockAlert(product);
      }

      debugPrint('✅ Product updated successfully: ${product.id}');
    } catch (e) {
      debugPrint('❌ Error updating product: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId, String tenantId) async {
    try {
      debugPrint('🗑️ Deleting product: $productId from tenant: $tenantId');
      await _firestoreService.deleteProduct(productId, tenantId);

      _products.removeWhere((p) => p.id == productId);
      notifyListeners();

      debugPrint('✅ Product deleted successfully: $productId');
    } catch (e) {
      debugPrint('❌ Error deleting product: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Helper method to check and create alerts
  Future<void> _checkAndCreateAlerts(Product product) async {
    // Check low stock
    if (product.qty <= product.reorderThreshold) {
      await _createLowStockAlert(product);
    }

    // Check expiry
    final daysUntilExpiry =
        product.expirationDate.difference(DateTime.now()).inDays;
    if (daysUntilExpiry <= 90 && daysUntilExpiry > 0) {
      await _createExpiryAlert(product, daysUntilExpiry);
    }
  }

  Future<void> _createLowStockAlert(Product product) async {
    try {
      final alertId =
          'low_stock_${product.id}_${DateTime.now().millisecondsSinceEpoch}';

      // Check if alert already exists for this product
      final existingAlert = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(product.tenantId)
          .collection('alerts')
          .where('productId', isEqualTo: product.id)
          .where('type', isEqualTo: 'low_stock')
          .where('resolved', isEqualTo: false)
          .get();

      // Don't create duplicate unresolved alerts
      if (existingAlert.docs.isNotEmpty) {
        debugPrint(
            '⚠️ Low stock alert already exists for product: ${product.meds}');
        return;
      }

      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(product.tenantId)
          .collection('alerts')
          .doc(alertId)
          .set({
        'id': alertId,
        'productId': product.id,
        'productName': product.meds,
        'type': 'low_stock',
        'severity': product.qty == 0 ? 'critical' : 'warning',
        'message':
            '⚠️ Low stock: ${product.meds} has only ${product.qty} units left (threshold: ${product.reorderThreshold})',
        'currentStock': product.qty,
        'threshold': product.reorderThreshold,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'resolved': false,
      });

      debugPrint('✅ Low stock alert created for: ${product.meds}');
    } catch (e) {
      debugPrint('❌ Failed to create low stock alert: $e');
    }
  }

  Future<void> _createExpiryAlert(Product product, int daysUntilExpiry) async {
    try {
      final alertId =
          'expiry_${product.id}_${DateTime.now().millisecondsSinceEpoch}';

      // Determine severity
      String severity = 'info';
      if (daysUntilExpiry <= 7) {
        severity = 'critical';
      } else if (daysUntilExpiry <= 30) {
        severity = 'warning';
      }

      // Check if alert already exists for this product
      final existingAlert = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(product.tenantId)
          .collection('alerts')
          .where('productId', isEqualTo: product.id)
          .where('type', isEqualTo: 'expiring')
          .where('resolved', isEqualTo: false)
          .get();

      // Don't create duplicate unresolved alerts
      if (existingAlert.docs.isNotEmpty) {
        debugPrint(
            '⚠️ Expiry alert already exists for product: ${product.meds}');
        return;
      }

      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(product.tenantId)
          .collection('alerts')
          .doc(alertId)
          .set({
        'id': alertId,
        'productId': product.id,
        'productName': product.meds,
        'lotNumber': product.lotNumber,
        'type': 'expiring',
        'severity': severity,
        'message':
            '📅 Expiring soon: ${product.meds} (Lot: ${product.lotNumber}) expires in $daysUntilExpiry days',
        'expiryDate': product.expirationDate,
        'daysUntilExpiry': daysUntilExpiry,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'resolved': false,
      });

      debugPrint('✅ Expiry alert created for: ${product.meds}');
    } catch (e) {
      debugPrint('❌ Failed to create expiry alert: $e');
    }
  }

  Future<void> resolveAlert(String tenantId, String alertId) async {
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('alerts')
          .doc(alertId)
          .update({
        'resolved': true,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Alert resolved: $alertId');
    } catch (e) {
      debugPrint('❌ Failed to resolve alert: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getActiveAlerts(String tenantId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('alerts')
          .where('resolved', isEqualTo: false)
          .orderBy('severity', descending: true)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('❌ Failed to get alerts: $e');
      return [];
    }
  }

  Future<void> refreshProducts(String tenantId) async {
    await loadProducts(tenantId);
  }
// lib/providers/product_provider.dart

// Add this method to resolve alerts automatically
  Future<void> _resolveAlertsForProduct(Product product) async {
    try {
      // Find all unresolved alerts for this product
      final alertsSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(product.tenantId)
          .collection('alerts')
          .where('productId', isEqualTo: product.id)
          .where('resolved', isEqualTo: false)
          .get();

      for (final alertDoc in alertsSnapshot.docs) {
        final alertData = alertDoc.data();
        final alertType = alertData['type'];

        bool shouldResolve = false;
        String resolveReason = '';

        if (alertType == 'low_stock' &&
            product.qty > product.reorderThreshold) {
          // Stock is now above threshold
          shouldResolve = true;
          resolveReason =
              'Stock replenished to ${product.qty} units (above threshold of ${product.reorderThreshold})';
        } else if (alertType == 'low_stock' && product.qty == 0) {
          // Product is out of stock (still alert, but change severity)
          shouldResolve = true;
          resolveReason = 'Product is out of stock (0 units remaining)';
        } else if (alertType == 'expiring' && product.isExpired) {
          // Product has expired
          shouldResolve = true;
          resolveReason = 'Product has expired';
        } else if (alertType == 'expiring' && product.qty == 0) {
          // Product is out of stock before expiry
          shouldResolve = true;
          resolveReason = 'Product is out of stock (0 units remaining)';
        } else if (alertType == 'critical' &&
            (product.qty == 0 || product.isExpired)) {
          // Critical alert resolved
          shouldResolve = true;
          resolveReason = product.qty == 0
              ? 'Product is out of stock'
              : 'Product has expired';
        }

        if (shouldResolve) {
          await alertDoc.reference.update({
            'resolved': true,
            'resolvedAt': FieldValue.serverTimestamp(),
            'resolvedReason': resolveReason,
          });
          debugPrint(
              '✅ Auto-resolved ${alertType} alert for product: ${product.meds} - $resolveReason');
        } else if (alertType == 'low_stock' &&
            product.qty <= product.reorderThreshold &&
            product.qty > 0) {
          // Update existing alert with new stock level
          await alertDoc.reference.update({
            'currentStock': product.qty,
            'message':
                '⚠️ Low stock: ${product.meds} has only ${product.qty} units left (threshold: ${product.reorderThreshold})',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint(
              '📝 Updated low stock alert for: ${product.meds} (now ${product.qty} units)');
        }
      }
    } catch (e) {
      debugPrint('❌ Error resolving alerts for product ${product.id}: $e');
    }
  }

  Future<void> resolveAllAlertsForTenant(String tenantId) async {
    try {
      final alertsSnapshot = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('alerts')
          .where('resolved', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in alertsSnapshot.docs) {
        batch.update(doc.reference, {
          'resolved': true,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedReason': 'Bulk resolve by admin',
        });
      }

      await batch.commit();
      debugPrint(
          '✅ Resolved ${alertsSnapshot.docs.length} alerts for tenant: $tenantId');
    } catch (e) {
      debugPrint('❌ Failed to resolve alerts: $e');
    }
  }
  // lib/providers/product_provider.dart

  List<Product> getFilteredProducts({
    String? search,
    String? category,
    String? sortBy,
  }) {
    var filtered = List<Product>.from(_products);

    // Apply search filter
    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p.meds.toLowerCase().contains(search.toLowerCase()) ||
              p.brand.toLowerCase().contains(search.toLowerCase()) ||
              p.lotNumber.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }

    // Apply category filter - FIXED: Don't filter if category is null or empty
    if (category != null &&
        category.isNotEmpty &&
        category != 'All Categories') {
      filtered = filtered.where((p) => p.category == category).toList();
    }

    // Apply sort
    switch (sortBy) {
      case 'az':
        filtered.sort((a, b) => a.meds.compareTo(b.meds));
        break;
      case 'za':
        filtered.sort((a, b) => b.meds.compareTo(a.meds));
        break;
      case 'qty-low':
        filtered.sort((a, b) => a.qty.compareTo(b.qty));
        break;
      case 'qty-high':
        filtered.sort((a, b) => b.qty.compareTo(a.qty));
        break;
      case 'expiry':
        filtered.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
        break;
    }

    return filtered;
  }

  Product? getProductByLotNumber(String lotNumber) {
    try {
      return _products.firstWhere(
        (product) => product.lotNumber.toLowerCase() == lotNumber.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  List<String> getCategories() {
    final categories = _products.map((p) => p.category).toSet().toList();
    categories.sort();
    return categories;
  }
}
