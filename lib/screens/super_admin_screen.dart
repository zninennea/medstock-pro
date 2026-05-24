// lib/screens/super_admin_screen.dart
import 'dart:ui';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../models/tenant.dart';
import '../widgets/payment_dialog.dart';
import '../services/print_service.dart';
import 'super_admin/tenant_management_screen.dart';
import 'package:excel/excel.dart' as excel;
import '../models/user.dart';
import '../services/firestore_service.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, bool> _paymentStatusMap = {};

  // Pagination variables
  int _tenantCurrentPage = 0;
  int _tenantItemsPerPage = 10;
  int _paymentCurrentPage = 0;
  int _paymentItemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadPaymentStatuses();
  }

  Future<void> _loadPaymentStatuses() async {
    final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
    final tenants = tenantProvider.tenants.values.toList();

    final Map<String, bool> statusMap = {};
    for (final tenant in tenants) {
      statusMap[tenant.id] = await _hasTenantPaid(tenant.id);
    }

    if (mounted) {
      setState(() {
        _paymentStatusMap = statusMap;
      });
    }
  }

  Future<bool> _hasTenantPaid(String tenantId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('tenantId', isEqualTo: tenantId)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking payment for $tenantId: $e');
      return false;
    }
  }

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

  Future<Map<String, bool>> _loadAllTenantPaymentStatus(
      List<Tenant> tenants) async {
    final Map<String, bool> statusMap = {};
    for (final tenant in tenants) {
      statusMap[tenant.id] = await _hasTenantPaid(tenant.id);
    }
    return statusMap;
  }

  void _printInvoice(String tenantName, double amount, String reference,
      String method, DateTime date) {
    final invoiceHtml = """
  <!DOCTYPE html>
  <html>
  <head>
    <title>Invoice - $reference</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 40px; }
      .invoice { max-width: 800px; margin: 0 auto; border: 1px solid #ddd; padding: 20px; border-radius: 10px; }
      .header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 10px; }
      .content { margin: 20px 0; }
      .footer { text-align: center; font-size: 12px; color: #666; margin-top: 20px; }
      table { width: 100%; border-collapse: collapse; }
      td { padding: 8px; }
    </style>
  </head>
  <body>
    <div class="invoice">
      <div class="header">
        <h2>MedStock Pro Invoice</h2>
        <p>Reference: $reference</p>
      </div>
      <div class="content">
        <table>
          <tr><td><strong>Tenant:</strong></td><td>$tenantName</td></tr>
          <tr><td><strong>Date:</strong></td><td>${DateFormat('yyyy-MM-dd HH:mm').format(date)}</td></tr>
          <tr><td><strong>Payment Method:</strong></td><td>$method</td></tr>
          <tr><td><strong>Amount:</strong></td><td>₱${amount.toStringAsFixed(2)}</td></tr>
        </table>
      </div>
      <div class="footer">
        <p>Thank you for using MedStock Pro!</p>
      </div>
    </div>
    <script>window.print();</script>
  </body>
  </html>
  """;

    final blob = html.Blob([invoiceHtml], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  void _showReceiptFromData(
      BuildContext context, String tenantName, String receiptData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Receipt - $tenantName'),
        content: SizedBox(
          width: 400,
          height: 500,
          child: Image.memory(
            base64Decode(receiptData),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) {
              return const Center(child: Text('Unable to load receipt image'));
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ============================================
  // RECEIPT VERIFICATION METHODS
  // ============================================

  Future<void> _verifyReceipt(String paymentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .update({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': 'Super Admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Receipt verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the payment status map to update UI
        await _loadPaymentStatuses();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error verifying receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error verifying receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReceiptViewer(BuildContext context, String tenantName,
      Map<String, dynamic> paymentData, String paymentId) {
    final isVerified = paymentData['isVerified'] ?? false;
    final receiptData = paymentData['receiptData'];
    final amount = (paymentData['amount'] as num?)?.toDouble() ?? 0;
    final method = paymentData['method'] ?? 'Cash';
    final reference = paymentData['reference'] ?? 'N/A';
    final timestamp =
        (paymentData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final period = (paymentData['period'] as Timestamp?)?.toDate();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isVerified ? Icons.verified : Icons.warning_amber_rounded,
                  color: isVerified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text('Receipt Verification: $tenantName'),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isVerified
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      border: Border.all(
                          color: isVerified
                              ? Colors.green.shade300
                              : Colors.red.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isVerified
                              ? Icons.check_circle
                              : Icons.cancel_outlined,
                          color: isVerified ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVerified
                              ? 'RECEIPT VERIFIED'
                              : 'PENDING VERIFICATION',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isVerified ? Colors.green : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReceiptDetailRow(
                      'Billing Period:',
                      period != null
                          ? '${period.year}-${period.month.toString().padLeft(2, '0')}'
                          : 'N/A'),
                  _buildReceiptDetailRow(
                      'Amount Paid:', '₱${amount.toStringAsFixed(2)}'),
                  _buildReceiptDetailRow('Payment Method:', method),
                  _buildReceiptDetailRow('Reference No:', reference),
                  _buildReceiptDetailRow('Payment Date:',
                      DateFormat('yyyy-MM-dd HH:mm').format(timestamp)),
                  const SizedBox(height: 16),
                  if (receiptData != null && receiptData.isNotEmpty) ...[
                    const Text('Receipt Image:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _showFullReceiptImage(context, receiptData),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(receiptData),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stack) {
                              return const Center(
                                  child: Text('Unable to load image'));
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () =>
                            _showFullReceiptImage(context, receiptData),
                        icon: const Icon(Icons.fullscreen, size: 16),
                        label: const Text('View Full Screen'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!isVerified)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Click "Verify Receipt" to mark this payment as verified.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              if (!isVerified)
                ElevatedButton.icon(
                  onPressed: () async {
                    await _verifyReceipt(paymentId);
                    Navigator.pop(dialogContext);
                    // Refresh the UI
                    setState(() {});
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Verify Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  _printInvoice(
                      tenantName, amount, reference, method, timestamp);
                },
                icon: const Icon(Icons.print),
                label: const Text('Print Invoice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showFullReceiptImage(BuildContext context, String receiptData) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Receipt Image',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(receiptData),
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);
    final tenants = tenantProvider.tenants.values.toList();
    final totalARR =
        tenants.fold<double>(0.0, (current, t) => current + t.billing * 12);
    final monthlyRevenue =
        tenants.fold<double>(0.0, (current, t) => current + t.billing);
    final totalProducts =
        tenants.fold<int>(0, (current, t) => current + t.products.length);
    final premiumCount =
        tenants.where((t) => t.tier == TenantTier.premium).length;
    final basicCount = tenants.length - premiumCount;
    final isMobile = MediaQuery.of(context).size.width < 1200;

    double totalPaid = 0;
    double totalPending = 0;

    for (final tenant in tenants) {
      if (_paymentStatusMap[tenant.id] == true) {
        totalPaid += tenant.billing;
      } else {
        totalPending += tenant.billing;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row - Responsive
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                return Column(
                  children: [
                    _buildSuperStatCard(context, 'Total ARR', totalARR,
                        Icons.trending_up, Colors.purple,
                        isCurrency: true),
                    const SizedBox(height: 12),
                    _buildSuperStatCard(
                      context,
                      'Active Tenants',
                      tenants.length.toDouble(),
                      Icons.business,
                      Colors.blue,
                      isCurrency: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('$premiumCount Premium',
                                  style: const TextStyle(fontSize: 10))),
                          const SizedBox(width: 4),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('$basicCount Basic',
                                  style: const TextStyle(fontSize: 10))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _buildSuperStatCard(
                                context,
                                'Total Products',
                                totalProducts.toDouble(),
                                Icons.inventory,
                                Colors.green,
                                isCurrency: false)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildSuperStatCard(
                                context,
                                'Monthly Revenue',
                                monthlyRevenue,
                                Icons.attach_money,
                                Colors.orange,
                                isCurrency: true)),
                      ],
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                        child: _buildSuperStatCard(context, 'Total ARR',
                            totalARR, Icons.trending_up, Colors.purple,
                            isCurrency: true)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildSuperStatCard(
                      context,
                      'Active Tenants',
                      tenants.length.toDouble(),
                      Icons.business,
                      Colors.blue,
                      isCurrency: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.indigo.shade100,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('$premiumCount Premium',
                                  style: const TextStyle(fontSize: 10))),
                          const SizedBox(width: 4),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text('$basicCount Basic',
                                  style: const TextStyle(fontSize: 10))),
                        ],
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildSuperStatCard(
                            context,
                            'Total Products',
                            totalProducts.toDouble(),
                            Icons.inventory,
                            Colors.green,
                            isCurrency: false)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildSuperStatCard(context, 'Monthly Revenue',
                            monthlyRevenue, Icons.attach_money, Colors.orange,
                            isCurrency: true)),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Payment Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Collection Summary',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _buildPaymentSummaryRow(
                      'Total Collected:', totalPaid, Colors.green),
                  const SizedBox(height: 8),
                  _buildPaymentSummaryRow(
                      'Pending Collection:', totalPending, Colors.orange),
                  const SizedBox(height: 8),
                  _buildPaymentSummaryRow(
                      'Collection Rate:',
                      totalPaid + totalPending > 0
                          ? (totalPaid / (totalPaid + totalPending) * 100)
                              .toStringAsFixed(1)
                          : '0',
                      Colors.blue,
                      isPercent: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Tenant Management Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tenant Management',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Row(
                        children: [
                          ElevatedButton.icon(
                              onPressed: () =>
                                  _showAddTenantDialog(context, tenantProvider),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Tenant'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade600,
                                  foregroundColor: Colors.white)),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const TenantManagementScreen())),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Open Manager'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Tenant Table - Responsive with horizontal scroll
                  SizedBox(
                    width: double.infinity,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: FutureBuilder<Map<String, bool>>(
                        future: _loadAllTenantPaymentStatus(tenants),
                        builder: (context, snapshot) {
                          final paymentStatusMap = snapshot.data ?? {};
                          final startIndex =
                              _tenantCurrentPage * _tenantItemsPerPage;
                          final endIndex = (startIndex + _tenantItemsPerPage) >
                                  tenants.length
                              ? tenants.length
                              : startIndex + _tenantItemsPerPage;
                          final pageTenants =
                              tenants.sublist(startIndex, endIndex);
                          final totalPages =
                              (tenants.length / _tenantItemsPerPage).ceil();

                          return Column(
                            children: [
                              DataTable(
                                columnSpacing: 12,
                                horizontalMargin: 12,
                                columns: const [
                                  DataColumn(label: Text('Tenant')),
                                  DataColumn(label: Text('Plan')),
                                  DataColumn(label: Text('Monthly')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: pageTenants.map((tenant) {
                                  final hasPaid =
                                      paymentStatusMap[tenant.id] ?? false;
                                  final isSuspended = tenant.suspended;
                                  return DataRow(cells: [
                                    DataCell(SizedBox(
                                      width: 180,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(tenant.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          Text(tenant.email,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600)),
                                        ],
                                      ),
                                    )),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color:
                                              tenant.tier == TenantTier.premium
                                                  ? Colors.green.shade100
                                                  : Colors.orange.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Text(tenant.tier.displayName,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold)),
                                    )),
                                    DataCell(Text(
                                        '₱${NumberFormat("#,##0.00").format(tenant.billing)}')),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: isSuspended
                                              ? Colors.orange.shade100
                                              : (hasPaid
                                                  ? Colors.green.shade100
                                                  : Colors.red.shade100),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: Text(
                                          isSuspended
                                              ? 'SUSPENDED'
                                              : (hasPaid ? 'PAID' : 'UNPAID'),
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isSuspended
                                                  ? Colors.orange.shade800
                                                  : (hasPaid
                                                      ? Colors.green.shade800
                                                      : Colors.red.shade800))),
                                    )),
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.payment,
                                              size: 18),
                                          onPressed: () async {
                                            final hasPaidThisMonth =
                                                await _hasTenantPaidThisMonth(
                                                    tenant.id);
                                            if (hasPaidThisMonth) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        '⚠️ Already paid this month'),
                                                    backgroundColor:
                                                        Colors.orange),
                                              );
                                              return;
                                            }
                                            final result = await showDialog(
                                              context: context,
                                              builder: (_) =>
                                                  PaymentDialog(tenant: tenant),
                                            );
                                            if (result == true) {
                                              await _loadPaymentStatuses();
                                              if (mounted) setState(() {});
                                            }
                                          },
                                          color: tenant.suspended
                                              ? Colors.grey
                                              : Colors.green,
                                          tooltip: tenant.suspended
                                              ? 'Cannot record payment for suspended tenant'
                                              : 'Record Payment',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.history,
                                              size: 18),
                                          onPressed: () =>
                                              _showAuditDialog(context, tenant),
                                          color: Colors.blue,
                                        ),
                                        IconButton(
                                          icon: Icon(
                                              !hasPaid && !tenant.suspended
                                                  ? Icons.mail
                                                  : Icons.mail_outline,
                                              size: 18),
                                          onPressed: (!hasPaid &&
                                                  !tenant.suspended)
                                              ? () => _showEmailSimulatorDialog(
                                                  context, tenant)
                                              : null,
                                          color: (!hasPaid && !tenant.suspended)
                                              ? Colors.red
                                              : Colors.grey,
                                          tooltip:
                                              (!hasPaid && !tenant.suspended)
                                                  ? 'Send Payment Reminder'
                                                  : 'No reminder needed',
                                        ),
                                      ],
                                    )),
                                  ]);
                                }).toList(),
                              ),
                              if (tenants.length > _tenantItemsPerPage)
                                _buildPagination(
                                  _tenantCurrentPage,
                                  totalPages,
                                  tenants.length,
                                  _tenantItemsPerPage,
                                  onPrevious: () =>
                                      setState(() => _tenantCurrentPage--),
                                  onNext: () =>
                                      setState(() => _tenantCurrentPage++),
                                  onPageChange: (page) =>
                                      setState(() => _tenantCurrentPage = page),
                                  onItemsPerPageChange: (value) => setState(() {
                                    _tenantItemsPerPage = value;
                                    _tenantCurrentPage = 0;
                                  }),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Platform Payment Audit Trail
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Platform Payment Audit Trail',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 450,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('payments')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                              child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                Icon(Icons.receipt_long,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No payments recorded yet.')
                              ]));
                        }

                        final payments = snapshot.data!.docs;
                        final totalPages =
                            (payments.length / _paymentItemsPerPage).ceil();
                        final startIndex =
                            _paymentCurrentPage * _paymentItemsPerPage;
                        final endIndex = (startIndex + _paymentItemsPerPage) >
                                payments.length
                            ? payments.length
                            : startIndex + _paymentItemsPerPage;
                        final pagePayments =
                            payments.sublist(startIndex, endIndex);

                        return Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 12,
                                  horizontalMargin: 12,
                                  columns: const [
                                    DataColumn(
                                        label: Text('Date',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Tenant',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Amount',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Method',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Reference',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                    DataColumn(
                                        label: Text('Actions',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold))),
                                  ],
                                  rows: pagePayments.map((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final timestamp =
                                        (data['timestamp'] as Timestamp?)
                                                ?.toDate() ??
                                            DateTime.now();
                                    final tenantName = data['tenantName'] ??
                                        data['tenantId'] ??
                                        'Unknown';
                                    final amount =
                                        (data['amount'] as num?)?.toDouble() ??
                                            0;
                                    final method = data['method'] ?? 'Cash';
                                    final reference =
                                        data['reference'] ?? 'N/A';
                                    final receiptData = data['receiptData'];
                                    final isVerified =
                                        data['isVerified'] ?? false;
                                    final paymentId = doc.id;

                                    return DataRow(cells: [
                                      DataCell(Text(
                                          DateFormat('MM/dd/yy HH:mm')
                                              .format(timestamp),
                                          style:
                                              const TextStyle(fontSize: 12))),
                                      DataCell(SizedBox(
                                          width: 140,
                                          child: Text(tenantName,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500),
                                              overflow:
                                                  TextOverflow.ellipsis))),
                                      DataCell(Text(
                                          '₱${amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold))),
                                      DataCell(Chip(
                                          label: Text(method),
                                          backgroundColor: method == 'GCash'
                                              ? Colors.blue.shade100
                                              : Colors.green.shade100)),
                                      DataCell(Text(reference,
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11))),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (receiptData != null)
                                              IconButton(
                                                icon: Icon(Icons.receipt,
                                                    size: 20,
                                                    color: isVerified
                                                        ? Colors.green
                                                        : Colors.orange),
                                                onPressed: () =>
                                                    _showReceiptViewer(
                                                        context,
                                                        tenantName,
                                                        data,
                                                        paymentId),
                                                tooltip:
                                                    'View & Verify Receipt',
                                              ),
                                            IconButton(
                                                icon: const Icon(Icons.print,
                                                    size: 20,
                                                    color: Colors.indigo),
                                                onPressed: () => _printInvoice(
                                                    tenantName,
                                                    amount,
                                                    reference,
                                                    method,
                                                    timestamp),
                                                tooltip: 'Print Invoice'),
                                          ],
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                            if (payments.length > _paymentItemsPerPage)
                              _buildPagination(
                                _paymentCurrentPage,
                                totalPages,
                                payments.length,
                                _paymentItemsPerPage,
                                onPrevious: () =>
                                    setState(() => _paymentCurrentPage--),
                                onNext: () =>
                                    setState(() => _paymentCurrentPage++),
                                onPageChange: (page) =>
                                    setState(() => _paymentCurrentPage = page),
                                onItemsPerPageChange: (value) => setState(() {
                                  _paymentItemsPerPage = value;
                                  _paymentCurrentPage = 0;
                                }),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(
    int currentPage,
    int totalPages,
    int totalItems,
    int itemsPerPage, {
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required Function(int) onPageChange,
    required Function(int) onItemsPerPageChange,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Show: ', style: TextStyle(fontSize: 12)),
              DropdownButton<int>(
                value: itemsPerPage,
                items: const [5, 10, 25, 50]
                    .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value',
                            style: const TextStyle(fontSize: 12))))
                    .toList(),
                onChanged: (value) => onItemsPerPageChange(value!),
              ),
              const SizedBox(width: 16),
              Text('Total: $totalItems items',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          Row(
            children: [
              Text(
                  'Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: currentPage > 0 ? onPrevious : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
              const SizedBox(width: 8),
              IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: currentPage < totalPages - 1 ? onNext : null,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuperStatCard(BuildContext context, String title,
      double numericValue, IconData icon, Color color,
      {bool isCurrency = false, Widget? child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.05), Colors.transparent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 20, color: color)),
                const SizedBox(width: 12),
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isCurrency
                  ? NumberFormat.currency(
                          locale: 'en_PH', symbol: '₱', decimalDigits: 0)
                      .format(numericValue)
                  : numericValue.toInt().toString(),
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            if (child != null) ...[const SizedBox(height: 8), child],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummaryRow(String label, dynamic value, Color color,
      {bool isPercent = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Text(
            isPercent
                ? '$value%'
                : NumberFormat.currency(locale: 'en_PH', symbol: '₱')
                    .format(value),
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _showAuditDialog(BuildContext context, Tenant tenant) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.payment, color: Colors.green),
          const SizedBox(width: 8),
          Text('Payment Audit Trail - ${tenant.name}')
        ]),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .where('tenantId', isEqualTo: tenant.id)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No payment records found')
                    ]));
              }

              final payments = snapshot.data!.docs;
              return ListView.separated(
                itemCount: payments.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final data = payments[index].data() as Map<String, dynamic>;
                  final paymentDate =
                      (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                  final method = data['method'] ?? 'Cash';
                  final reference = data['reference'] ?? 'N/A';
                  final period = (data['period'] as Timestamp?)?.toDate();
                  final isVerified = data['isVerified'] ?? false;
                  final receiptData = data['receiptData'];
                  final periodStr = period != null
                      ? '${period.year}-${period.month.toString().padLeft(2, '0')}'
                      : 'N/A';

                  return ListTile(
                    leading: CircleAvatar(
                        backgroundColor: isVerified
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        child: Icon(
                            isVerified ? Icons.check_circle : Icons.pending,
                            size: 20)),
                    title: Row(children: [
                      Text('₱${amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: method == 'GCash'
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(method)),
                      const SizedBox(width: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: isVerified
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(isVerified ? 'VERIFIED' : 'PENDING'))
                    ]),
                    subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Period: $periodStr'),
                          Text('Reference: $reference'),
                          Text(
                              'Recorded: ${DateFormat('yyyy-MM-dd HH:mm').format(paymentDate)}')
                        ]),
                    trailing: receiptData != null
                        ? IconButton(
                            icon: const Icon(Icons.receipt),
                            onPressed: () => _showReceiptFromData(
                                ctx, tenant.name, receiptData))
                        : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          TextButton.icon(
              onPressed: () => _exportPaymentHistoryFromFirestore(
                  ctx, tenant.id, tenant.name),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Export to Excel')),
        ],
      ),
    );
  }

  void _exportPaymentHistoryFromFirestore(
      BuildContext context, String tenantId, String tenantName) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('tenantId', isEqualTo: tenantId)
          .orderBy('timestamp', descending: true)
          .get();
      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No payment records to export'),
            backgroundColor: Colors.orange));
        return;
      }

      final excelFile = excel.Excel.createExcel();
      final sheet = excelFile['Payment History'];
      sheet.appendRow([
        excel.TextCellValue('Date'),
        excel.TextCellValue('Period'),
        excel.TextCellValue('Amount (₱)'),
        excel.TextCellValue('Payment Method'),
        excel.TextCellValue('Reference'),
        excel.TextCellValue('Status')
      ]);

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final paymentDate =
            (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
        final period = (data['period'] as Timestamp?)?.toDate();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0;
        final method = data['method'] ?? 'Cash';
        final reference = data['reference'] ?? 'N/A';
        final isVerified = data['isVerified'] ?? false;
        final periodStr = period != null
            ? '${period.year}-${period.month.toString().padLeft(2, '0')}'
            : 'N/A';
        sheet.appendRow([
          excel.TextCellValue(
              DateFormat('yyyy-MM-dd HH:mm').format(paymentDate)),
          excel.TextCellValue(periodStr),
          excel.DoubleCellValue(amount),
          excel.TextCellValue(method),
          excel.TextCellValue(reference),
          excel.TextCellValue(isVerified ? 'Verified' : 'Pending')
        ]);
      }

      final excelBytes = excelFile.save();
      if (excelBytes == null) return;
      PrintService.downloadFile(excelBytes,
          'payment_history_${tenantName}_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Payment history exported successfully!'),
          backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error exporting: $e'), backgroundColor: Colors.red));
    }
  }

  void _showAddTenantDialog(
      BuildContext context, TenantProvider tenantProvider) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final emailController = TextEditingController();
    String selectedTier = 'Basic';
    double billing = 4500;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Tenant'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Tenant Name'),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: emailController,
                      decoration:
                          const InputDecoration(labelText: 'Admin Email'),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedTier,
                    decoration:
                        const InputDecoration(labelText: 'Subscription Plan'),
                    items: const [
                      DropdownMenuItem(
                          value: 'Basic', child: Text('Basic (₱4,500/mo)')),
                      DropdownMenuItem(
                          value: 'Premium', child: Text('Premium (₱12,500/mo)'))
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedTier = value!;
                        billing = selectedTier == 'Basic' ? 4500 : 12500;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final loadingSnackBar = SnackBar(
                    content: Row(
                      children: const [
                        SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Creating tenant...'),
                      ],
                    ),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 10),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(loadingSnackBar);

                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  final tenantId =
                      nameController.text.toLowerCase().replaceAll(' ', '_');
                  final normalizedTenantId = tenantId.toLowerCase().trim();
                  final adminEmail = emailController.text.toLowerCase().trim();

                  // Check if tenant already exists FIRST
                  final existingTenant =
                      await _firestoreService.getTenant(normalizedTenantId);
                  if (existingTenant != null) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              '❌ Tenant ID already exists. Please use a different name.'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  // Check if email already exists in Firebase Auth
                  bool emailExists = false;
                  try {
                    final methods = await authProvider.firebaseAuth
                        .fetchSignInMethodsForEmail(adminEmail);
                    if (methods.isNotEmpty) emailExists = true;
                  } catch (e) {
                    emailExists = false;
                  }

                  if (emailExists) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('❌ Admin email already exists: $adminEmail'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  try {
                    // Create tenant in Firestore
                    await tenantProvider.registerTenant(
                      id: normalizedTenantId,
                      name: nameController.text,
                      address: addressController.text,
                      tier: selectedTier == 'Basic'
                          ? TenantTier.basic
                          : TenantTier.premium,
                      billing: billing,
                      email: adminEmail,
                    );

                    // Create admin account in Firebase Auth
                    final created = await authProvider.createAdminAccount(
                      superAdminEmail: authProvider.currentUser?.email ??
                          'superadmin@medstock.pro',
                      adminEmail: adminEmail,
                      adminName: '${nameController.text} Admin',
                      tenantId: normalizedTenantId,
                      password: 'admin123',
                    );

                    ScaffoldMessenger.of(context).hideCurrentSnackBar();

                    if (created) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '✅ Tenant created! Admin: $adminEmail / admin123'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      await _loadPaymentStatuses();
                      await tenantProvider.refreshTenants();
                      if (mounted) {
                        setState(() {});
                      }
                    } else {
                      // Only delete tenant if admin creation failed AND tenant was just created
                      // Don't delete if admin already existed (we already checked above)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              '❌ Failed to create admin account. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create Tenant'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmailSimulatorDialog(BuildContext context, Tenant tenant) {
    final subject = '[MedStock Pro] ⚠️ Subscription Payment Reminder';
    var bodyText =
        'Dear Admin of ${tenant.name},\n\nThis is a payment reminder for your MedStock Pro Workspace.\n\nYour monthly billing cycle renewal is currently due.\nPlan Tier: ${tenant.tier.displayName}\nBilling Due: PhP ${NumberFormat("#,##0.00").format(tenant.billing)}\nStatus: ${tenant.paymentStatus.displayName.toUpperCase()}\n\nTo maintain full syncing access, please settle the outstanding invoice amount.\n\nThank you for choosing MedStock Pro!\n\nBest Regards,\nMedStock Pro Super Admin';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.email_outlined, color: Colors.indigo),
          SizedBox(width: 8),
          Text('Simulate Billing Reminder Email')
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: Column(children: [
                    _buildEmailHeaderRow('From:', 'superadmin@medstock.pro'),
                    const Divider(),
                    _buildEmailHeaderRow('To:', tenant.email),
                    const Divider(),
                    _buildEmailHeaderRow('Subject:', subject)
                  ])),
              const SizedBox(height: 16),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(bodyText)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.send),
              label: const Text('Simulate Send')),
        ],
      ),
    );
  }

  Widget _buildEmailHeaderRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey))),
      Expanded(child: Text(value))
    ]);
  }
}
