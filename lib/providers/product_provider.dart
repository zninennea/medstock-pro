// lib/providers/product_provider.dart
import 'package:flutter/material.dart';
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
      debugPrint(
          '✅ Loaded ${_products.length} products from tenants/$tenantId/products');
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

      // Add to local list
      _products.add(product);
      notifyListeners();

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
      await _firestoreService.updateProduct(product);

      final index = _products.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }

      // Check and create alerts for low stock
      if (product.qty <= product.reorderThreshold) {
        await _firestoreService.createLowStockAlert(
          product.tenantId,
          product.meds,
          product.qty,
          product.reorderThreshold,
        );
      }

      // Check and create alerts for expiring soon
      final daysUntilExpiry =
          product.expirationDate.difference(DateTime.now()).inDays;
      if (daysUntilExpiry <= 90) {
        await _firestoreService.createExpiryAlert(
          product.tenantId,
          product.meds,
          product.lotNumber,
          daysUntilExpiry,
        );
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId, String tenantId) async {
    try {
      debugPrint('🗑️ Deleting product: $productId from tenant: $tenantId');
      await _firestoreService.deleteProduct(productId, tenantId);

      // Remove from local list
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

  Future<void> refreshProducts(String tenantId) async {
    await loadProducts(tenantId);
  }

  List<Product> getFilteredProducts({
    String? search,
    String? category,
    String? sortBy,
  }) {
    var filtered = List<Product>.from(_products);

    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where((p) =>
              p.meds.toLowerCase().contains(search.toLowerCase()) ||
              p.brand.toLowerCase().contains(search.toLowerCase()) ||
              p.lotNumber.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }

    if (category != null &&
        category.isNotEmpty &&
        category != 'All Categories') {
      filtered = filtered.where((p) => p.category == category).toList();
    }

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
