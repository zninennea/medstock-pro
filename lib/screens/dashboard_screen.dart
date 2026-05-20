// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../models/tenant.dart';
import '../models/product.dart';
import '../widgets/stats_card.dart';
import '../widgets/billing_card.dart';
import '../models/transaction.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tenantProvider = Provider.of<TenantProvider>(context);
    final tenant =
        tenantProvider.getCurrentTenant(authProvider.currentTenantId!);

    if (tenant == null) {
      return const Center(child: Text('No tenant data'));
    }

    final totalProducts = tenant.products.length;
    final alertCount = tenant.alertCount;
    final inventoryValue = NumberFormat.currency(locale: 'en_PH', symbol: '₱')
        .format(tenant.totalInventoryValue);

    final totalOut = tenant.transactions
        .where((t) => t.type == TransactionType.stockOut)
        .fold(0, (sum, t) => sum + t.qty);
    final avgInventory = tenant.products.fold(0, (sum, p) => sum + p.qty) /
        (tenant.products.isEmpty ? 1 : tenant.products.length);
    final turnoverRate = avgInventory > 0
        ? (totalOut / avgInventory * 100).toStringAsFixed(1)
        : '0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Subscription Alert Banner
          if (tenant.paymentStatus != PaymentStatus.paid) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: tenant.paymentStatus == PaymentStatus.overdue
                      ? [Colors.red.shade800, Colors.red.shade600]
                      : [Colors.orange.shade800, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (tenant.paymentStatus == PaymentStatus.overdue ? Colors.red : Colors.orange).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    tenant.paymentStatus == PaymentStatus.overdue ? Icons.error : Icons.warning_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tenant.paymentStatus == PaymentStatus.overdue
                              ? '🚨 SUBSCRIPTION PAYMENT OVERDUE'
                              : '⚠️ SUBSCRIPTION RENEWAL APPROACHING',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tenant.paymentStatus == PaymentStatus.overdue
                              ? 'Your premium subscription has elapsed. Please settle PhP ${NumberFormat("#,##0.00").format(tenant.billing)} immediately to maintain uninterrupted database sync access.'
                              : 'Your subscription cycle renewal payment is due. Please process your monthly billing of PhP ${NumberFormat("#,##0.00").format(tenant.billing)} to avoid service interruption.',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Stats Row
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Total Products',
                  value: totalProducts.toString(),
                  icon: Icons.inventory,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Low/Expiring',
                  value: alertCount.toString(),
                  icon: Icons.warning,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Inventory Value',
                  value: inventoryValue,
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  title: 'Turnover Rate',
                  value: '$turnoverRate%',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Billing Info
          BillingCard(tenant: tenant),
          const SizedBox(height: 16),

          // Charts would go here - using Placeholder for brevity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stock Value by Category',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: _buildCategoryChart(tenant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Top Movers
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Movers (30 days)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ..._getTopMovers(tenant).map((mover) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(mover['name']),
                            Text(
                              '+${mover['in']} / -${mover['out']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                  if (_getTopMovers(tenant).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('No data yet')),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Expiry Calendar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expiry Calendar (Next 90 days)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ..._getExpiringProducts(tenant).map((product) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${product.meds} (${product.lotNumber})',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Text(
                              '${product.expirationDate.difference(DateTime.now()).inDays} days',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    product.isExpiringSoon ? Colors.red : null,
                                fontWeight: product.isExpiringSoon
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (_getExpiringProducts(tenant).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: Text('No expiring products')),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChart(Tenant tenant) {
    // Simple bar chart representation
    final Map<String, double> categoryValues = {};
    for (final product in tenant.products) {
      final category = product.category;
      categoryValues[category] =
          (categoryValues[category] ?? 0) + (product.qty * product.cost);
    }

    final categories = categoryValues.keys.toList();
    final values = categoryValues.values.toList();

    if (categories.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        final maxValue =
            values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
        final height = (values[index] / maxValue) * 150;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 50,
              height: height,
              decoration: BoxDecoration(
                color: Colors.blue.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              categories[index],
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
            ),
            Text(
              NumberFormat.currency(
                      locale: 'en_PH', symbol: '₱', decimalDigits: 0)
                  .format(values[index]),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _getTopMovers(Tenant tenant) {
    final Map<String, Map<String, int>> movements = {};

    for (final transaction in tenant.transactions) {
      final name = transaction.productName;
      if (!movements.containsKey(name)) {
        movements[name] = {'in': 0, 'out': 0};
      }
      if (transaction.type == TransactionType.stockIn) {
        movements[name]!['in'] = movements[name]!['in']! + transaction.qty;
      } else {
        movements[name]!['out'] = movements[name]!['out']! + transaction.qty;
      }
    }

    final movers = movements.entries
        .map((e) => {
              'name': e.key,
              'in': e.value['in'],
              'out': e.value['out'],
              'total': (e.value['in'] ?? 0) + (e.value['out'] ?? 0),
            })
        .toList();

    movers.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));
    return movers.take(5).toList();
  }

  List<Product> _getExpiringProducts(Tenant tenant) {
    final now = DateTime.now();
    final ninetyDays = now.add(const Duration(days: 90));

    return tenant.products
        .where((p) =>
            p.expirationDate.isAfter(now) &&
            p.expirationDate.isBefore(ninetyDays))
        .toList()
      ..sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
  }
}
