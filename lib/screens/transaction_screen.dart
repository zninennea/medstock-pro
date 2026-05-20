// lib/screens/transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../models/product.dart';
import '../models/transaction.dart' as model;
import '../models/transaction_item.dart';
import '../providers/product_provider.dart';
import '../models/tenant.dart';
import '../models/user.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  model.TransactionType _transactionType = model.TransactionType.stockIn;
  final List<TransactionItem> _items = [];
  final _referenceController = TextEditingController();
  String _selectedStaff = '';
  bool _isSubmitting = false;

  // Set to track processed transaction IDs to prevent duplicates
  final Set<String> _processedTransactionIds = {};

  // Pagination for transaction history
  int _historyCurrentPage = 0;
  int _historyItemsPerPage = 10;
  List<model.Transaction> _recentTransactions = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _referenceController.text = _generateReference();
    _addItem();
    _loadStaffList();
    _loadRecentTransactions();
  }

  void _loadStaffList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserName = authProvider.currentUser?.name ?? 'Staff User';
    _selectedStaff = currentUserName;
  }

  Future<void> _loadRecentTransactions() async {
    setState(() => _isLoadingHistory = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
    final tenantId = authProvider.currentTenantId ?? 'davmedical';
    final tenant = tenantProvider.getCurrentTenant(tenantId);

    if (tenant != null) {
      setState(() {
        _recentTransactions = tenant.transactions.toList();
      });
    }
    setState(() => _isLoadingHistory = false);
  }

  String _generateReference() {
    return 'TRX-${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 13)}';
  }

  void _addItem() {
    setState(() {
      _items.add(TransactionItem(
        qty: 1,
        reason: _transactionType.reasons.first,
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItemProduct(int index, Product? product) {
    setState(() {
      if (product != null) {
        _items[index].product = product;
        _items[index].lotNumber = product.lotNumber;
        _items[index].details =
            '${product.meds} | ${product.brand} | Stock: ${product.qty}';
        _items[index].currentStock = product.qty;
        _items[index].expiry =
            product.expirationDate.toIso8601String().split('T')[0];
        _items[index].uom = product.uom;
        _items[index].meds = product.meds;
      } else {
        _items[index].product = null;
      }
    });
  }

  void _updateItemQty(int index, int qty) {
    setState(() {
      _items[index].qty = qty.clamp(1, 9999);
    });
  }

  void _updateItemReason(int index, String reason) {
    setState(() {
      _items[index].reason = reason;
    });
  }

  Future<void> _submitTransaction() async {
    if (_isSubmitting) return;

    final validItems =
        _items.where((item) => item.product != null && item.qty > 0).toList();

    if (validItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    for (final item in validItems) {
      if (_transactionType == model.TransactionType.stockOut &&
          item.product!.qty < item.qty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Insufficient stock for ${item.product!.meds}. Available: ${item.product!.qty}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    _showConfirmationSheet(validItems);
  }

  void _showConfirmationSheet(List<TransactionItem> validItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 16),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.inventory,
                          color:
                              _transactionType == model.TransactionType.stockIn
                                  ? Colors.green
                                  : Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Confirm Batch Transaction',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: _transactionType ==
                                    model.TransactionType.stockIn
                                ? Colors.green
                                : Colors.red),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 16,
                          columns: const [
                            DataColumn(label: Text('Product')),
                            DataColumn(label: Text('Lot#')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Qty')),
                            DataColumn(label: Text('BAL After')),
                          ],
                          rows: validItems.map((item) {
                            final p = item.product!;
                            final balAfter = _transactionType ==
                                    model.TransactionType.stockIn
                                ? p.qty + item.qty
                                : p.qty - item.qty;
                            return DataRow(
                              cells: [
                                DataCell(Text(p.meds,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500))),
                                DataCell(Text(p.lotNumber,
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11))),
                                DataCell(Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _transactionType ==
                                            model.TransactionType.stockIn
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _transactionType.displayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _transactionType ==
                                              model.TransactionType.stockIn
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                )),
                                DataCell(Text(item.qty.toString())),
                                DataCell(Text(
                                  balAfter.toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildInfoRow('Reference:', _referenceController.text),
                      _buildInfoRow('Staff:', _selectedStaff),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This transaction will be recorded in the audit trail and cannot be undone.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.blue.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _processTransactions(validItems);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _transactionType ==
                                    model.TransactionType.stockIn
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Confirm & Process'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _processTransactions(List<TransactionItem> validItems) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final tenantId = authProvider.currentTenantId ?? 'davmedical';

    final staffName = authProvider.currentUser?.name ?? 'Unknown Staff';
    final staffId = authProvider.currentUser?.id ?? 'unknown';

    // Generate a unique batch ID for this transaction batch
    final batchId = DateTime.now().millisecondsSinceEpoch.toString();

    // Check if this batch was already processed (prevent double submission)
    if (_processedTransactionIds.contains(batchId)) {
      debugPrint('⚠️ Duplicate transaction batch detected, skipping...');
      return;
    }

    _processedTransactionIds.add(batchId);

    // Clear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _processedTransactionIds.remove(batchId);
    });

    setState(() => _isSubmitting = true);

    // Process each item
    for (final item in validItems) {
      final product = item.product!;
      int newQty = product.qty;
      if (_transactionType == model.TransactionType.stockIn) {
        newQty += item.qty;
      } else {
        newQty -= item.qty;
      }

      // Update product
      final updatedProduct = product.copyWith(qty: newQty);
      await productProvider.updateProduct(updatedProduct);

      // Generate unique transaction ID
      final transactionId = '${batchId}_${product.id}';

      // Check if transaction already exists
      final existingTransaction = await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('transactions')
          .doc(transactionId)
          .get();

      if (existingTransaction.exists) {
        debugPrint('⚠️ Transaction already exists, skipping: $transactionId');
        continue;
      }

      // Create transaction record using model.Transaction
      final transaction = model.Transaction(
        id: transactionId,
        productId: product.id,
        productName: product.meds,
        lotNumber: product.lotNumber,
        type: _transactionType,
        qty: item.qty,
        reason: item.reason,
        reference: _referenceController.text,
        staffId: staffId,
        staffName: staffName,
        timestamp: DateTime.now(),
        balAfter: newQty,
        tenantId: tenantId,
        productDetails: {
          'meds': product.meds,
          'brand': product.brand,
          'uom': product.uom,
          'cost': product.cost,
          'srp': product.srp,
        },
      );

      // Save to Firestore
      await tenantProvider.addTransaction(tenantId, transaction);

      // Generate unique audit ID
      final auditId = '${batchId}_audit_${product.id}';

      // Add to audit trail
      final actionStr = _transactionType == model.TransactionType.stockIn
          ? 'Stock In'
          : 'Stock Out';
      final detailsStr = _transactionType == model.TransactionType.stockIn
          ? 'Restocked ${item.qty} units of ${product.meds} (${product.lotNumber}) - ${item.reason}'
          : 'Dispensed ${item.qty} units of ${product.meds} (${product.lotNumber}) - ${item.reason}';

      await tenantProvider.addAuditEntryWithId(
        tenantId,
        auditId,
        AuditEntry(
          timestamp: DateTime.now(),
          action: actionStr,
          details: detailsStr,
          user: staffName,
          role: authProvider.currentUser?.role ?? UserRole.staff,
        ),
      );
    }

    // Refresh recent transactions
    await _loadRecentTransactions();

    // Show success message
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          authProvider.isOnline
              ? '✅ Transaction completed: ${validItems.length} item(s) processed'
              : '🟠 Offline Mode: ${validItems.length} transaction(s) queued',
        ),
        backgroundColor:
            authProvider.isOnline ? Colors.green : Colors.orange.shade800,
        duration: const Duration(seconds: 3),
      ),
    );

    // Reset form
    setState(() {
      _items.clear();
      _addItem();
      _referenceController.text = _generateReference();
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = Provider.of<ProductProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final paginatedTransactions = _getPaginatedTransactions();
    final totalPages =
        (_recentTransactions.length / _historyItemsPerPage).ceil();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transaction Type Toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                      child: _buildTypeButton(
                          model.TransactionType.stockIn, isDark)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildTypeButton(
                          model.TransactionType.stockOut, isDark)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Transaction Items
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ..._items.asMap().entries.map(
                        (entry) => _buildTransactionItem(entry.key, entry.value,
                            productProvider.products, isDark),
                      ),
                  Center(
                    child: TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Another Product'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Reference and Staff
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _referenceController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Reference Number',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.receipt),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _selectedStaff,
                    readOnly: true,
                    enabled: false,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Staff Member',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: const Icon(Icons.lock, size: 16),
                      helperText: 'Auto-filled from your account',
                      filled: true,
                      fillColor: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Transaction',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

          const SizedBox(height: 24),

          // Recent Transactions Section with Pagination
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Recent Transactions',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingHistory)
                    const Center(child: CircularProgressIndicator())
                  else if (_recentTransactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No transactions recorded yet.'),
                      ),
                    )
                  else
                    Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 12,
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Lot#')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Qty')),
                              DataColumn(label: Text('Balance')),
                              DataColumn(label: Text('Reason')),
                            ],
                            rows: paginatedTransactions.map((transaction) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(
                                    DateFormat('MM/dd HH:mm')
                                        .format(transaction.timestamp),
                                    style: const TextStyle(fontSize: 11),
                                  )),
                                  DataCell(Text(transaction.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500))),
                                  DataCell(Text(transaction.lotNumber,
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11))),
                                  DataCell(Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: transaction.type ==
                                              model.TransactionType.stockIn
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      transaction.type.displayName,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: transaction.type ==
                                                model.TransactionType.stockIn
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  )),
                                  DataCell(Text('${transaction.qty}')),
                                  DataCell(Text('${transaction.balAfter}')),
                                  DataCell(Text(transaction.reason,
                                      style: const TextStyle(fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPaginationControls(totalPages),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<model.Transaction> _getPaginatedTransactions() {
    final startIndex = _historyCurrentPage * _historyItemsPerPage;
    final endIndex =
        (startIndex + _historyItemsPerPage) > _recentTransactions.length
            ? _recentTransactions.length
            : startIndex + _historyItemsPerPage;
    return _recentTransactions.sublist(startIndex, endIndex);
  }

  Widget _buildPaginationControls(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text('Show: ', style: TextStyle(fontSize: 12)),
            DropdownButton<int>(
              value: _historyItemsPerPage,
              items: const [5, 10, 25, 50].map((value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value', style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _historyItemsPerPage = value;
                    _historyCurrentPage = 0;
                  });
                }
              },
            ),
            const SizedBox(width: 16),
            Text(
              'Total: ${_recentTransactions.length} transactions',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              'Page ${_historyCurrentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: _historyCurrentPage > 0
                  ? () => setState(() => _historyCurrentPage--)
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: _historyCurrentPage < totalPages - 1
                  ? () => setState(() => _historyCurrentPage++)
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeButton(model.TransactionType type, bool isDark) {
    final isSelected = _transactionType == type;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _transactionType = type;
          _items.clear();
          _addItem();
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Colors.blue.shade600
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        foregroundColor: isSelected
            ? Colors.white
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              type == model.TransactionType.stockIn
                  ? Icons.inventory
                  : Icons.local_hospital,
              size: 18),
          const SizedBox(width: 8),
          Text(type.displayName),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
      int index, TransactionItem item, List<Product> products, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Item ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (index > 0)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => _removeItem(index),
                  color: Colors.red,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Autocomplete<Product>(
            key: ValueKey('auto_${index}_${item.hashCode}'),
            initialValue: item.product != null
                ? TextEditingValue(
                    text:
                        '${item.product!.lotNumber} - ${item.product!.meds} | ${item.product!.brand}')
                : TextEditingValue.empty,
            displayStringForOption: (Product product) =>
                '${product.lotNumber} - ${product.meds} | ${product.brand}',
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) return products;
              final query = textEditingValue.text.toLowerCase();
              return products.where((Product product) {
                return product.lotNumber.toLowerCase().contains(query) ||
                    product.meds.toLowerCase().contains(query) ||
                    product.brand.toLowerCase().contains(query);
              }).toList();
            },
            onSelected: (Product selection) =>
                _updateItemProduct(index, selection),
            fieldViewBuilder:
                (context, textEditingController, focusNode, onFieldSubmitted) {
              return TextFormField(
                controller: textEditingController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: 'Search Lot# or Product...',
                  labelText: 'Select Product',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  suffixIcon: item.product != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            textEditingController.clear();
                            _updateItemProduct(index, null);
                          },
                        )
                      : const Icon(Icons.search),
                ),
                onFieldSubmitted: (value) => onFieldSubmitted(),
              );
            },
          ),
          const SizedBox(height: 12),
          if (item.product != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(item.details ?? '',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Expiry: ${item.expiry ?? 'N/A'}',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: item.qty.toString(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity (${item.uom ?? 'units'})',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) {
                      final qty = int.tryParse(value) ?? 1;
                      _updateItemQty(index, qty);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: item.reason.isNotEmpty ? item.reason : null,
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _transactionType.reasons
                        .map((reason) => DropdownMenuItem(
                              value: reason,
                              child: Text(reason,
                                  style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (reason) => _updateItemReason(index, reason!),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }
}
