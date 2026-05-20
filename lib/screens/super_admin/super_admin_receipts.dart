// lib/screens/super_admin/super_admin_receipts.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SuperAdminReceiptsScreen extends StatefulWidget {
  const SuperAdminReceiptsScreen({super.key});

  @override
  State<SuperAdminReceiptsScreen> createState() =>
      _SuperAdminReceiptsScreenState();
}

class _SuperAdminReceiptsScreenState extends State<SuperAdminReceiptsScreen> {
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, verified, pending
  String _filterMethod = 'all'; // all, cash, gcash

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Payment Receipts'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                // Search field
                SizedBox(
                  width: isMobile ? double.infinity : 250,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by tenant...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                // Status filter
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Status')),
                      DropdownMenuItem(
                          value: 'verified', child: Text('Verified')),
                      DropdownMenuItem(
                          value: 'pending', child: Text('Pending')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterStatus = value!;
                      });
                    },
                  ),
                ),
                // Method filter
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Method',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    value: _filterMethod,
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All Methods')),
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filterMethod = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('superAdmin')
                  .doc('superadmin')
                  .collection('receipts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No receipts found'),
                        SizedBox(height: 8),
                        Text(
                            'Receipts will appear here when payments are recorded'),
                      ],
                    ),
                  );
                }

                var receipts = snapshot.data!.docs;

                // Apply filters
                receipts = receipts.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final tenantName = (data['tenantName'] ?? '').toLowerCase();
                  final matchesSearch =
                      _searchQuery.isEmpty || tenantName.contains(_searchQuery);
                  final matchesStatus = _filterStatus == 'all' ||
                      (_filterStatus == 'verified' &&
                          data['verified'] == true) ||
                      (_filterStatus == 'pending' && data['verified'] != true);
                  final matchesMethod =
                      _filterMethod == 'all' || data['method'] == _filterMethod;
                  return matchesSearch && matchesStatus && matchesMethod;
                }).toList();

                if (receipts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_alt_off,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No receipts match your filters'),
                      ],
                    ),
                  );
                }

                // Use ListView.builder for both mobile and desktop to avoid height constraints
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: receipts.length,
                  itemBuilder: (context, index) {
                    final doc = receipts[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildReceiptCard(data, doc.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> data, String docId) {
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isVerified = data['verified'] ?? false;
    final amount = (data['amount'] ?? 0).toDouble();
    final method = data['method'] ?? 'Cash';
    final tenantName = data['tenantName'] ?? 'Unknown Tenant';
    final reference = data['reference'] ?? 'N/A';
    final receiptData = data['receiptData'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor:
              isVerified ? Colors.green.shade100 : Colors.orange.shade100,
          child: Icon(
            isVerified ? Icons.verified : Icons.pending,
            color: isVerified ? Colors.green : Colors.orange,
            size: 20,
          ),
        ),
        title: Text(
          tenantName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Row(
          children: [
            Text('₱${amount.toStringAsFixed(2)}'),
            const SizedBox(width: 12),
            Text(DateFormat('MM/dd/yyyy').format(createdAt),
                style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Chip(
          label: Text(method, style: const TextStyle(fontSize: 11)),
          backgroundColor:
              method == 'GCash' ? Colors.blue.shade100 : Colors.green.shade100,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Reference:', reference),
                _buildDetailRow('Status:',
                    isVerified ? 'Verified ✓' : 'Pending Verification'),
                _buildDetailRow(
                    'Date:', DateFormat('yyyy-MM-dd HH:mm').format(createdAt)),
                const SizedBox(height: 12),
                if (receiptData != null && receiptData.toString().isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showReceiptPreview(context, receiptData.toString()),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Receipt'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                if (!isVerified) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _verifyReceipt(docId),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Verify Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyReceipt(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('superAdmin')
          .doc('superadmin')
          .collection('receipts')
          .doc(docId)
          .update({
        'verified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': 'Super Admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Receipt verified!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReceiptPreview(BuildContext context, String receiptData) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receipt Preview'),
        content: SizedBox(
          width: 400,
          height: 500,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(receiptData),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) {
                return const Center(
                    child: Text('Unable to load receipt image'));
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
