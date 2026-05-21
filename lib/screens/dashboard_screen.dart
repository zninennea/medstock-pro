// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../models/tenant.dart';
import '../models/product.dart';
import '../widgets/stats_card.dart';
import '../widgets/billing_card.dart';
import '../models/transaction.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _hasPaid = false;
  bool _isLoadingPaymentStatus = true;
  double _tenantBilling = 0;
  String _tenantName = '';
  String _tenantTier = '';

  @override
  void initState() {
    super.initState();
    _checkPaymentStatus();
  }

  Future<void> _checkPaymentStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
    final tenantId = authProvider.currentTenantId;

    // Get tenant info for billing
    if (tenantId != null && !authProvider.isSuperAdmin) {
      final tenant = tenantProvider.getCurrentTenant(tenantId);
      if (tenant != null) {
        setState(() {
          _tenantBilling = tenant.billing;
          _tenantName = tenant.name;
          _tenantTier = tenant.tier.displayName;
        });
      }
    }

    if (tenantId != null && !authProvider.isSuperAdmin) {
      try {
        // Query payments directly from Firestore
        final snapshot = await FirebaseFirestore.instance
            .collection('payments')
            .where('tenantId', isEqualTo: tenantId)
            .get();

        final hasPayment = snapshot.docs.isNotEmpty;

        setState(() {
          _hasPaid = hasPayment;
          _isLoadingPaymentStatus = false;
        });

        debugPrint(
            '✅ Payment status for $tenantId: $hasPayment (found ${snapshot.docs.length} payments)');
      } catch (e) {
        debugPrint('Error checking payment status: $e');
        setState(() {
          _hasPaid = false;
          _isLoadingPaymentStatus = false;
        });
      }
    } else {
      setState(() {
        _isLoadingPaymentStatus = false;
      });
    }
  }

  Future<void> _refreshPaymentStatus() async {
    await _checkPaymentStatus();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tenantProvider = Provider.of<TenantProvider>(context);
    final tenant = authProvider.currentTenantId != null
        ? tenantProvider.getCurrentTenant(authProvider.currentTenantId!)
        : null;

    if (tenant == null && !authProvider.isSuperAdmin) {
      return const Center(child: Text('No tenant data'));
    }

    // For Super Admin, show different dashboard
    if (authProvider.isSuperAdmin) {
      return _buildSuperAdminDashboard(tenantProvider);
    }

    final totalProducts = tenant!.products.length;
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

    // Determine payment status based on actual Firestore query
    final paymentStatus = _isLoadingPaymentStatus
        ? PaymentStatus.pending
        : (_hasPaid ? PaymentStatus.paid : PaymentStatus.overdue);

    return RefreshIndicator(
      onRefresh: _refreshPaymentStatus,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Subscription Alert Banner
            if (paymentStatus != PaymentStatus.paid) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: paymentStatus == PaymentStatus.overdue
                        ? [Colors.red.shade800, Colors.red.shade600]
                        : [Colors.orange.shade800, Colors.orange.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (paymentStatus == PaymentStatus.overdue
                              ? Colors.red
                              : Colors.orange)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      paymentStatus == PaymentStatus.overdue
                          ? Icons.error
                          : Icons.warning_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            paymentStatus == PaymentStatus.overdue
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
                            paymentStatus == PaymentStatus.overdue
                                ? 'Your subscription has elapsed. Please settle PhP ${NumberFormat("#,##0.00").format(_tenantBilling)} immediately to maintain uninterrupted access.'
                                : 'Your subscription renewal payment is due. Please process your monthly billing of PhP ${NumberFormat("#,##0.00").format(_tenantBilling)} to avoid service interruption.',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
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
            _buildBillingCard(),
            const SizedBox(height: 16),

            // Stock Value by Category Chart
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
                                  color: product.isExpiringSoon
                                      ? Colors.red
                                      : null,
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
      ),
    );
  }

  Widget _buildBillingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Billing Information',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Plan',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600)),
                          Text(_tenantTier,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Billing',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600)),
                          Text('₱${_tenantBilling.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Status',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _hasPaid
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _hasPaid ? 'PAID' : 'UNPAID',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _hasPaid ? Colors.green : Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuperAdminDashboard(TenantProvider tenantProvider) {
    final tenants = tenantProvider.tenants.values.toList();
    final totalTenants = tenants.length;
    final totalProducts = tenants.fold(0, (sum, t) => sum + t.products.length);
    final totalRevenue = tenants.fold(0.0, (sum, t) => sum + t.billing);

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Dashboard',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatsCard(
                    title: 'Total Tenants',
                    value: totalTenants.toString(),
                    icon: Icons.business,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatsCard(
                    title: 'Total Products',
                    value: totalProducts.toString(),
                    icon: Icons.inventory,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatsCard(
                    title: 'Monthly Revenue',
                    value: NumberFormat.currency(locale: 'en_PH', symbol: '₱')
                        .format(totalRevenue),
                    icon: Icons.attach_money,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatsCard(
                    title: 'Active Tenants',
                    value: tenants.where((t) => !t.suspended).length.toString(),
                    icon: Icons.check_circle,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(Tenant tenant) {
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
