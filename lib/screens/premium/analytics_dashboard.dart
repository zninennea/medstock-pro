// lib/screens/premium/analytics_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../models/product.dart';
import '../../models/transaction.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  String _selectedPeriod = '30days';
  late Map<String, int> _topMovers;
  late Map<String, int> _slowMovers;
  int _totalTransactionsCount = 0;
  int _totalStockMoved = 0;
  String _championMover = 'N/A';
  int _championMoverQty = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
    final tenant =
        tenantProvider.getCurrentTenant(authProvider.currentTenantId!);

    if (tenant != null) {
      _topMovers = _calculateTopMovers(tenant.transactions, _selectedPeriod);
      _slowMovers = _calculateSlowMovers(
          tenant.transactions, tenant.products, _selectedPeriod);

      // Compute KPI summaries
      final days = _selectedPeriod == '30days'
          ? 30
          : _selectedPeriod == '7days'
              ? 7
              : 90;
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      final periodTxns = tenant.transactions
          .where((t) => t.timestamp.isAfter(cutoffDate))
          .toList();

      _totalTransactionsCount = periodTxns.length;
      _totalStockMoved = periodTxns.fold(0, (sum, t) => sum + t.qty);

      if (_topMovers.isNotEmpty) {
        _championMover = _topMovers.keys.first;
        _championMoverQty = _topMovers.values.first;
      } else {
        _championMover = 'N/A';
        _championMoverQty = 0;
      }
    }
  }

  Map<String, int> _calculateTopMovers(
      List<Transaction> transactions, String period) {
    final days = period == '30days'
        ? 30
        : period == '7days'
            ? 7
            : 90;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    final filteredTransactions =
        transactions.where((t) => t.timestamp.isAfter(cutoffDate)).toList();

    final Map<String, int> movement = {};
    for (final transaction in filteredTransactions) {
      final total = movement[transaction.productName] ?? 0;
      movement[transaction.productName] = total + transaction.qty;
    }

    final entries = movement.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries.take(5));
  }

  Map<String, int> _calculateSlowMovers(
      List<Transaction> transactions, List<Product> products, String period) {
    final days = period == '30days'
        ? 30
        : period == '7days'
            ? 7
            : 90;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    final recentTransactions =
        transactions.where((t) => t.timestamp.isAfter(cutoffDate)).toList();
    final movedProducts = recentTransactions.map((t) => t.productName).toSet();

    final Map<String, int> slowMovers = {};
    for (final product in products) {
      if (!movedProducts.contains(product.meds)) {
        slowMovers[product.meds] = product.qty;
      }
    }

    final entries = slowMovers.entries.toList();
    entries.sort((a, b) => a.value.compareTo(b.value));
    return Map.fromEntries(entries.take(5));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Header with Period Selector Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Premium Analytics Dashboard',
                    style: TextStyle(
                      fontSize: 26, 
                      fontWeight: FontWeight.w800, 
                      color: Colors.indigo,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time inventory velocity & movement tracking',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              // Segmented modern toggle buttons
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildPeriodTab('7days', '7 Days'),
                    _buildPeriodTab('30days', '30 Days'),
                    _buildPeriodTab('90days', '90 Days'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KPI Summary Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = constraints.maxWidth > 800
                  ? (constraints.maxWidth - 32) / 3
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildKpiCard(
                    title: 'TOTAL MOVEMENT VOLUME',
                    value: _totalStockMoved.toString(),
                    subtitle: '$_totalTransactionsCount individual transactions',
                    icon: Icons.swap_vert,
                    colors: [Colors.indigo.shade700, Colors.blue.shade600],
                    width: cardWidth,
                  ),
                  _buildKpiCard(
                    title: 'CHAMPION VELOCITY ITEM',
                    value: _championMover,
                    subtitle: 'Moved $_championMoverQty units in this period',
                    icon: Icons.trending_up,
                    colors: [Colors.purple.shade700, Colors.pink.shade500],
                    width: cardWidth,
                  ),
                  _buildKpiCard(
                    title: 'CRITICAL INACTIVE STOCK',
                    value: '${_slowMovers.length} Items',
                    subtitle: 'Zero transactions recorded',
                    icon: Icons.hourglass_empty_rounded,
                    colors: [Colors.orange.shade700, Colors.red.shade500],
                    width: cardWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Main Visual Charts Grid
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 950) {
                // Side-by-side desktop view
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTopMoversCard(isDark)),
                    const SizedBox(width: 24),
                    Expanded(child: _buildSlowMoversCard(isDark)),
                  ],
                );
              } else {
                // Stacked mobile view
                return Column(
                  children: [
                    _buildTopMoversCard(isDark),
                    const SizedBox(height: 24),
                    _buildSlowMoversCard(isDark),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab(String value, String label) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPeriod = value;
          _loadAnalytics();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required double width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              icon,
              size: 80,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopMoversCard(bool isDark) {
    final maxVal = _topMovers.isEmpty
        ? 10.0
        : _topMovers.values.reduce((a, b) => a > b ? a : b).toDouble();
    final chartMaxY = maxVal == 0 ? 10.0 : maxVal * 1.25;

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flash_on, color: Colors.indigo, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  '🏆 High-Velocity Movers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 260,
              child: _topMovers.isEmpty
                  ? const Center(
                      child: Text('No transaction volume recorded in this period'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: chartMaxY,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.indigo.shade800,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final key = _topMovers.keys.elementAt(groupIndex);
                              return BarTooltipItem(
                                '$key\n',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: '${rod.toY.toInt()} Units Moved',
                                    style: const TextStyle(color: Colors.pinkAccent, fontSize: 12, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        barGroups: _topMovers.entries.map((entry) {
                          final index = _topMovers.keys.toList().indexOf(entry.key);
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.toDouble(),
                                gradient: LinearGradient(
                                  colors: [Colors.indigo.shade600, Colors.pink.shade400],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 26,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < _topMovers.keys.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SizedBox(
                                      width: 60,
                                      child: Text(
                                        _topMovers.keys.elementAt(index),
                                        style: TextStyle(
                                          fontSize: 9, 
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade600
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlowMoversCard(bool isDark) {
    final maxVal = _slowMovers.isEmpty
        ? 10.0
        : _slowMovers.values.reduce((a, b) => a > b ? a : b).toDouble();
    final chartMaxY = maxVal == 0 ? 10.0 : maxVal * 1.25;

    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.hourglass_bottom, color: Colors.orange.shade700, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  '🐌 Dormant & Inactive Stocks',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 260,
              child: _slowMovers.isEmpty
                  ? const Center(
                      child: Text('Outstanding! All items have active transaction velocities.'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: chartMaxY,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.orange.shade800,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final key = _slowMovers.keys.elementAt(groupIndex);
                              return BarTooltipItem(
                                '$key\n',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: 'Balance: ${rod.toY.toInt()} Units',
                                    style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        barGroups: _slowMovers.entries.map((entry) {
                          final index = _slowMovers.keys.toList().indexOf(entry.key);
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.toDouble(),
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade600, Colors.red.shade400],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 26,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < _slowMovers.keys.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SizedBox(
                                      width: 60,
                                      child: Text(
                                        _slowMovers.keys.elementAt(index),
                                        style: TextStyle(
                                          fontSize: 9, 
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade600
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
