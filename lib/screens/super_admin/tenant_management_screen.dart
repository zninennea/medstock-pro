  // lib/screens/super_admin/tenant_management_screen.dart
  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';
  import 'package:intl/intl.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import '../../services/firestore_service.dart';
  import '../../providers/auth_provider.dart';
  import '../../providers/tenant_provider.dart';
  import '../../models/tenant.dart';
  import '../../models/user.dart';
  import '../../widgets/payment_dialog.dart';

  enum TenantFilter { all, unpaid, paid, suspended }

  class TenantManagementScreen extends StatefulWidget {
    const TenantManagementScreen({super.key});

    @override
    State<TenantManagementScreen> createState() => _TenantManagementScreenState();
  }

  class _TenantManagementScreenState extends State<TenantManagementScreen> {
    final FirestoreService _firestoreService = FirestoreService();
    List<Map<String, dynamic>> _tenants = [];
    TenantFilter _filter = TenantFilter.all;
    bool _isLoading = true;

    @override
    void initState() {
      super.initState();
      _loadTenantsWithPaymentStatus();
    }

    // Replace the existing method with this one that checks for ANY payment record
  // Replace the existing method with this one that checks for ANY payment record
    Future<bool> _hasTenantPaid(String tenantId) async {
      try {
        // Check if there's ANY payment record for this tenant
        final snapshot = await FirebaseFirestore.instance
            .collection('payments')
            .where('tenantId', isEqualTo: tenantId)
            .limit(1)
            .get();

        return snapshot.docs.isNotEmpty;
      } catch (e) {
        debugPrint('Error checking payment for $tenantId: $e');
        return false;
      }
    }

  // Then update _loadTenantsWithPaymentStatus to use this:
    Future<void> _loadTenantsWithPaymentStatus() async {
      setState(() => _isLoading = true);

      try {
        _tenants = await _firestoreService.getAllTenants();

        final List<Future> futures = [];
        for (int i = 0; i < _tenants.length; i++) {
          final tenantId = _tenants[i]['id'] as String;
          // Make sure suspended status is read correctly
          final isSuspended = _tenants[i]['suspended'] == true;
          _tenants[i]['suspended'] = isSuspended;

          futures.add(_hasTenantPaid(tenantId).then((hasPaid) {
            _tenants[i]['paid'] = hasPaid;
          }));
        }

        await Future.wait(futures);
      } catch (e) {
        debugPrint('Error loading tenants: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }

    Future<void> _refreshTenants() async {
      await _loadTenantsWithPaymentStatus();
    }

    String _getDaysUntilPayment(DateTime nextPaymentDate) {
      final now = DateTime.now();
      final daysLeft = nextPaymentDate.difference(now).inDays;
      if (daysLeft < 0) return 'Overdue';
      if (daysLeft == 0) return 'Due today';
      return '$daysLeft days left';
    }

    Color _getPaymentTimerColor(DateTime nextPaymentDate) {
      final daysLeft = nextPaymentDate.difference(DateTime.now()).inDays;
      if (daysLeft < 0) return Colors.red;
      if (daysLeft <= 7) return Colors.orange;
      return Colors.green;
    }

    Future<void> _addTenant() async {
      final formKey = GlobalKey<FormState>();
      final nameController = TextEditingController();
      final addressController = TextEditingController();
      final emailController = TextEditingController();
      String selectedTier = 'Basic';
      double billing = 4500;

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add New Tenant'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    autofillHints: const [AutofillHints.organizationName],
                    decoration: const InputDecoration(labelText: 'Tenant Name'),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    autofillHints: const [AutofillHints.fullStreetAddress],
                    decoration: const InputDecoration(labelText: 'Address'),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Admin Email'),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedTier,
                    decoration:
                        const InputDecoration(labelText: 'Subscription Plan'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Basic', child: Text('Basic (₱4,500/mo)')),
                      DropdownMenuItem(
                          value: 'Premium', child: Text('Premium (₱12,500/mo)')),
                    ],
                    onChanged: (value) {
                      selectedTier = value!;
                      billing = selectedTier == 'Basic' ? 4500 : 12500;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final tenantId =
                      nameController.text.toLowerCase().replaceAll(' ', '_');
                  final normalizedTenantId = tenantId.toLowerCase().trim();
                  final adminEmail = emailController.text.toLowerCase().trim();
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  final tenantProvider =
                      Provider.of<TenantProvider>(context, listen: false);

                  if (_tenants.any((tenant) =>
                      (tenant['email'] as String?)?.toLowerCase().trim() ==
                      adminEmail)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Email already exists.'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  final existingTenant =
                      await _firestoreService.getTenant(normalizedTenantId);
                  if (existingTenant != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Tenant ID already exists.'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  final created = await authProvider.createAdminAccount(
                    superAdminEmail: authProvider.currentUser?.email ??
                        'superadmin@medstock.pro',
                    adminEmail: adminEmail,
                    adminName: '${nameController.text} Admin',
                    tenantId: normalizedTenantId,
                    password: 'admin123',
                  );

                  if (!created) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Unable to create tenant admin.'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  final tenantData = {
                    'name': nameController.text,
                    'address': addressController.text,
                    'tier': selectedTier,
                    'billing': billing,
                    'email': adminEmail,
                    'suspended': false,
                  };
                  await _firestoreService.addTenant(
                      normalizedTenantId, tenantData);
                  await _firestoreService.getProducts(normalizedTenantId);
                  await tenantProvider.addAuditEntry(
                    normalizedTenantId,
                    AuditEntry(
                      timestamp: DateTime.now(),
                      action: 'Tenant Created',
                      details:
                          'Tenant created by ${authProvider.currentUser?.email ?? 'superadmin'}',
                      user: authProvider.currentUser?.email ?? 'superadmin',
                      role: authProvider.currentUser?.role ?? UserRole.superAdmin,
                    ),
                  );

                  Navigator.pop(context);
                  await _loadTenantsWithPaymentStatus();
                  await tenantProvider.refreshTenants();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '✅ Tenant added. Admin: $adminEmail / admin123')),
                  );
                }
              },
              child: const Text('Add Tenant'),
            ),
          ],
        ),
      );
    }

    Future<void> _recordPayment(Map<String, dynamic> tenant) async {
      final tenantObj = Tenant.fromJson(tenant);
      final tenantId = tenant['id'] as String;
      final isSuspended = tenant['suspended'] == true;
      final isPaid = tenant['paid'] == true;

      // Check if tenant is suspended
      if (isSuspended) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Cannot record payment for a suspended tenant. Reactivate first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check if tenant has already paid this month
      final hasPaidThisMonth = await _hasTenantPaidThisMonth(tenantId);

      if (hasPaidThisMonth) {
        // Show month name in message
        final monthName = DateFormat('MMMM yyyy').format(DateTime.now());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ This tenant has already paid for $monthName.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => PaymentDialog(tenant: tenantObj),
      );

      if (result == true) {
        await _refreshTenants();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Payment recorded and tenant status updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }

    // Add this method to check if tenant has paid for current month
    Future<bool> _hasTenantPaidThisMonth(String tenantId) async {
      try {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);

        final snapshot = await FirebaseFirestore.instance
            .collection('payments')
            .where('tenantId', isEqualTo: tenantId)
            .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
            .where('timestamp', isLessThanOrEqualTo: endOfMonth)
            .get();

        return snapshot.docs.isNotEmpty;
      } catch (e) {
        debugPrint('Error checking monthly payment for $tenantId: $e');
        return false;
      }
    }

    Future<void> _suspendTenant(String tenantId, String name) async {
      // Check if tenant is paid before allowing suspension
      final tenant = _tenants.firstWhere((t) => t['id'] == tenantId);
      final isPaid = tenant['paid'] == true;

      if (isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot suspend a paid tenant. Mark as unpaid first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(
          title: const Text('Confirm Suspension'),
          content:
              Text('Suspend tenant "$name"? Suspended tenants cannot log in.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('Suspend')),
          ],
        ),
      );

      if (confirm != true) return;

      // Update Firestore
      await _firestoreService.updateTenant(tenantId, {'suspended': true});

      // Update local state immediately
      for (var i = 0; i < _tenants.length; i++) {
        if (_tenants[i]['id'] == tenantId) {
          _tenants[i]['suspended'] = true;
          break;
        }
      }

      // Refresh from Firestore to be sure
      await _refreshTenants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Tenant "$name" has been suspended')),
        );
      }
    }

    Future<void> _activateTenant(String tenantId, String name) async {
      await _firestoreService.updateTenant(tenantId, {'suspended': false});

      // Update local state immediately
      for (var i = 0; i < _tenants.length; i++) {
        if (_tenants[i]['id'] == tenantId) {
          _tenants[i]['suspended'] = false;
          break;
        }
      }

      await _refreshTenants();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Tenant "$name" has been activated')),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      final filteredTenants = _tenants.where((tenant) {
        final isSuspended = tenant['suspended'] == true;
        final isPaid = tenant['paid'] == true;
        switch (_filter) {
          case TenantFilter.unpaid:
            return !isPaid && !isSuspended;
          case TenantFilter.paid:
            return isPaid && !isSuspended;
          case TenantFilter.suspended:
            return isSuspended;
          case TenantFilter.all:
            return true;
        }
      }).toList();

      return Scaffold(
        appBar: AppBar(
          title: const Text('Tenant Management'),
          actions: [
            IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addTenant,
                tooltip: 'Add Tenant'),
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshTenants,
                tooltip: 'Refresh'),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 10,
                      children: [
                        _buildFilterChip(
                            TenantFilter.all, 'All', _tenants.length),
                        _buildFilterChip(
                            TenantFilter.paid,
                            'Paid',
                            _tenants
                                .where((t) =>
                                    t['paid'] == true && t['suspended'] != true)
                                .length),
                        _buildFilterChip(
                            TenantFilter.unpaid,
                            'Unpaid',
                            _tenants
                                .where((t) =>
                                    t['paid'] != true && t['suspended'] != true)
                                .length),
                        _buildFilterChip(TenantFilter.suspended, 'Suspended',
                            _tenants.where((t) => t['suspended'] == true).length),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshTenants,
                      child: filteredTenants.isEmpty
                          ? Center(
                              child: Text('No tenants match.',
                                  style: TextStyle(color: Colors.grey.shade600)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredTenants.length,
                              itemBuilder: (context, index) {
                                final tenant = filteredTenants[index];
                                final nameRaw = (tenant['name'] as String?) ?? '';
                                final displayName = nameRaw.isNotEmpty
                                    ? nameRaw
                                    : (tenant['id'] as String? ?? 'Unknown');
                                final initial = displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?';
                                final email =
                                    (tenant['email'] as String?)?.trim() ??
                                        'No email';
                                final isSuspended = tenant['suspended'] == true;
                                final isPaid = tenant['paid'] == true;
                                final billing =
                                    (tenant['billing'] as num?)?.toDouble() ?? 0;
                                final tier =
                                    tenant['tier']?.toString() ?? 'Basic';
                                final address =
                                    tenant['address'] as String? ?? 'No address';
                                final nextPaymentDate =
                                    DateTime.now().add(const Duration(days: 30));
                                final daysUntilPayment =
                                    _getDaysUntilPayment(nextPaymentDate);
                                final timerColor =
                                    _getPaymentTimerColor(nextPaymentDate);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: tier == 'Premium'
                                          ? Colors.indigo.shade100
                                          : Colors.grey.shade200,
                                      child: Text(initial,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: tier == 'Premium'
                                                  ? Colors.indigo.shade800
                                                  : Colors.grey.shade800)),
                                    ),
                                    title: Text(displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(email,
                                            style: const TextStyle(fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            _buildStatusChip(isPaid, isSuspended),
                                            _buildPaymentChip(tier),
                                            if (!isSuspended)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                    color: timerColor.withValues(
                                                        alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.timer,
                                                        size: 14,
                                                        color: timerColor),
                                                    const SizedBox(width: 4),
                                                    Text(daysUntilPayment,
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: timerColor)),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Suspend button - ONLY SHOW FOR UNPAID TENANTS (not suspended, not paid)
                                        if (!isSuspended && !isPaid)
                                          IconButton(
                                            icon: const Icon(Icons.pause_circle,
                                                color: Colors.orange),
                                            tooltip: 'Suspend tenant',
                                            onPressed: () => _suspendTenant(
                                                tenant['id'] as String,
                                                displayName),
                                          ),
                                        // Reactivate button - show only if suspended
                                        if (isSuspended)
                                          IconButton(
                                            icon: const Icon(Icons.play_circle,
                                                color: Colors.green),
                                            tooltip: 'Activate tenant',
                                            onPressed: () => _activateTenant(
                                                tenant['id'] as String,
                                                displayName),
                                          ),
                                        // Payment button (small icon) - disable if suspended
                                        IconButton(
                                          icon: Icon(Icons.payment,
                                              color: isSuspended
                                                  ? Colors.grey
                                                  : Colors.green),
                                          tooltip: isSuspended
                                              ? 'Cannot record payment for suspended tenant'
                                              : 'Record Payment',
                                          onPressed: isSuspended
                                              ? null
                                              : () => _recordPayment(tenant),
                                        ),
                                      ],
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Divider(),
                                            const SizedBox(height: 8),
                                            _buildInfoRow('Tenant ID:',
                                                tenant['id'] as String? ?? 'N/A'),
                                            _buildInfoRow('Address:', address),
                                            _buildInfoRow('Plan:', '$tier Plan'),
                                            _buildInfoRow('Monthly Billing:',
                                                '₱${billing.toStringAsFixed(2)}'),
                                            _buildInfoRow(
                                                'Status:',
                                                isSuspended
                                                    ? 'Suspended'
                                                    : (isPaid
                                                        ? 'Active - Paid'
                                                        : 'Active - Unpaid')),
                                            _buildInfoRow('Payment Status:',
                                                isPaid ? '✅ Paid' : '⚠️ Unpaid'),

                                            // Optional: Add "Already paid this month" indicator
                                            FutureBuilder<bool>(
                                              future: _hasTenantPaidThisMonth(
                                                  tenant['id'] as String),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasData &&
                                                    snapshot.data == true) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.green.shade50,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                        border: Border.all(
                                                            color: Colors
                                                                .green.shade200),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.check_circle,
                                                              size: 16,
                                                              color: Colors.green
                                                                  .shade700),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              '✓ Paid for ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                                                              style: TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .green
                                                                      .shade700),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
      );
    }

    Widget _buildInfoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 120,
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13))),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );
    }

    Widget _buildFilterChip(TenantFilter filter, String label, int count) {
      final selected = _filter == filter;
      return FilterChip(
        label: Text('$label ($count)'),
        selected: selected,
        onSelected: (_) => setState(() => _filter = filter),
      );
    }

    Widget _buildStatusChip(bool isPaid, bool isSuspended) {
      if (isSuspended) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause_circle, size: 12, color: Colors.orange.shade800),
              const SizedBox(width: 4),
              Text(
                'SUSPENDED',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
        );
      }
      if (isPaid) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 12, color: Colors.green.shade800),
              const SizedBox(width: 4),
              Text(
                'PAID',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 12, color: Colors.red.shade800),
            const SizedBox(width: 4),
            Text(
              'UNPAID',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildPaymentChip(String tier) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color:
                tier == 'Premium' ? Colors.indigo.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12)),
        child: Text(tier.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: tier == 'Premium'
                    ? Colors.indigo.shade800
                    : Colors.grey.shade700)),
      );
    }
  }
