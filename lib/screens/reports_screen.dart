// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../widgets/contact_sales_card.dart';
import 'premium/analytics_dashboard.dart';
import 'premium/premium_reports_screen.dart';
import '../models/tenant.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tenantProvider = Provider.of<TenantProvider>(context);
    final tenant =
        tenantProvider.getCurrentTenant(authProvider.currentTenantId!);

    // Check if user has access to reports (Admin only)
    final isAdmin = authProvider.isAdmin;
    final isPremium = tenant?.tier == TenantTier.premium;

    // Staff can't access reports at all
    if (!isAdmin) {
      return const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 48),
                SizedBox(height: 16),
                Text('Access Restricted',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Reports are only available for Admin users.'),
              ],
            ),
          ),
        ),
      );
    }

    // Basic tier - show contact sales
    if (!isPremium) {
      return const ContactSalesCard();
    }

    // Premium tier - show full reports
    return Column(
      children: [
        // Tab Bar
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              _buildTab('Analytics', 0),
              _buildTab('Reports', 1),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: IndexedStack(
            index: _selectedTab,
            children: const [
              AnalyticsDashboard(),
              PremiumReportsScreen(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blue.shade600 : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
