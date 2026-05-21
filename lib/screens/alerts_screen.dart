// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final products = productProvider.products;

    // Generate alerts dynamically from products
    final alerts = _getAlertsFromProducts(products);

    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green.shade400),
            const SizedBox(height: 16),
            const Text('All products healthy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('No low stock or expiring products',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.currentTenantId != null) {
          await productProvider.refreshProducts(authProvider.currentTenantId!);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: alerts.length,
        itemBuilder: (context, index) {
          final alert = alerts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: alert.backgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: alert.iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(alert.icon, color: alert.iconColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.product.meds,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text('Lot: ${alert.product.lotNumber}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Text(
                          alert.message,
                          style: TextStyle(
                              fontSize: 14,
                              color: alert.iconColor,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  if (alert.type != AlertType.expired)
                    IconButton(
                      icon: const Icon(Icons.shopping_cart, color: Colors.blue),
                      onPressed: () {
                        // Navigate to restock
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Go to Record IN/OUT to restock'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      tooltip: 'Restock',
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Alert> _getAlertsFromProducts(List<Product> products) {
    final now = DateTime.now();
    final alerts = <Alert>[];

    for (final product in products) {
      final daysUntilExpiry = product.expirationDate.difference(now).inDays;

      // Critical: Expired + Low Stock
      if (product.isExpired && product.isLowStock) {
        alerts.add(Alert(
          product: product,
          type: AlertType.expiredLow,
          message: '⚠️ EXPIRED + Low Stock (${product.qty} left)',
          icon: Icons.warning_amber,
          iconColor: Colors.red.shade900,
          backgroundColor: Colors.red.shade50,
        ));
      }
      // Expired
      else if (product.isExpired) {
        alerts.add(Alert(
          product: product,
          type: AlertType.expired,
          message: '⚠️ EXPIRED on ${_formatDate(product.expirationDate)}',
          icon: Icons.warning,
          iconColor: Colors.red,
          backgroundColor: Colors.red.shade50,
        ));
      }
      // Critical: Low Stock + Expiring Soon
      else if (product.isExpiringSoon && product.isLowStock) {
        alerts.add(Alert(
          product: product,
          type: AlertType.critical,
          message:
              '🚨 CRITICAL: Low Stock (${product.qty} left) + Expires in $daysUntilExpiry days',
          icon: Icons.warning_amber,
          iconColor: Colors.red.shade700,
          backgroundColor: Colors.red.shade50,
        ));
      }
      // Expiring Soon
      else if (product.isExpiringSoon) {
        alerts.add(Alert(
          product: product,
          type: AlertType.expiring,
          message:
              '📅 Expiring soon: ${_formatDate(product.expirationDate)} ($daysUntilExpiry days left)',
          icon: Icons.calendar_today,
          iconColor: Colors.orange.shade800,
          backgroundColor: Colors.orange.shade50,
        ));
      }
      // Low Stock
      else if (product.isLowStock) {
        alerts.add(Alert(
          product: product,
          type: AlertType.lowStock,
          message:
              '📦 Low stock: ${product.qty} left (Reorder at ${product.reorderThreshold})',
          icon: Icons.inventory,
          iconColor: Colors.orange.shade800,
          backgroundColor: Colors.orange.shade50,
        ));
      }
    }

    // Sort by priority: critical first, then expired, then expiring, then low stock
    alerts.sort((a, b) => a.type.priority.compareTo(b.type.priority));
    return alerts;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class Alert {
  final Product product;
  final AlertType type;
  final String message;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  Alert({
    required this.product,
    required this.type,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });
}

enum AlertType {
  critical,
  expiredLow,
  expired,
  expiring,
  lowStock,
}

extension AlertTypePriority on AlertType {
  int get priority {
    switch (this) {
      case AlertType.critical:
        return 0;
      case AlertType.expiredLow:
        return 1;
      case AlertType.expired:
        return 2;
      case AlertType.expiring:
        return 3;
      case AlertType.lowStock:
        return 4;
    }
  }
}
