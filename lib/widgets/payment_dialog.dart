// lib/widgets/payment_dialog.dart
import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tenant.dart';
import '../services/firestore_service.dart';

class PaymentDialog extends StatefulWidget {
  final Tenant tenant;

  const PaymentDialog({super.key, required this.tenant});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _paymentMethod = 'Cash';
  final _amountController = TextEditingController();
  DateTime _selectedPeriod = DateTime.now();
  String? _receiptUrl;
  bool _isUploading = false;
  String? _fileName;
  Uint8List? _fileBytes;
  bool _isImage = false;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isProcessing = false;
  String? _receiptDownloadUrl;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.tenant.billing.toString();
  }

  Future<void> _pickAndUploadReceipt() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType
            .custom, // FIXED: Changed from FileType.image to FileType.custom
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        setState(() {
          _isUploading = true;
        });

        await Future.delayed(const Duration(milliseconds: 500));

        final bytes = file.bytes;
        if (bytes != null) {
          final base64Image = base64Encode(bytes);
          _receiptDownloadUrl =
              'data:image/${file.extension};base64,$base64Image';
        }

        setState(() {
          _isUploading = false;
          _fileName = file.name;
          _fileBytes = file.bytes;
          _isImage = true;
          _receiptUrl = _receiptDownloadUrl;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ Receipt uploaded'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error uploading: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showReceiptPreview() {
    if (_fileBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Container(
          width: 400,
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Receipt Preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_fileBytes!, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Payment'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tenant: ${widget.tenant.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Plan: ${widget.tenant.tier.displayName}'),
                    Text('Monthly billing: ₱${widget.tenant.billing}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildMethodButton('Cash', Icons.money)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMethodButton('GCash', Icons.qr_code)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₱)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Payment Period'),
                subtitle:
                    Text('${_selectedPeriod.year}-${_selectedPeriod.month}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedPeriod,
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() => _selectedPeriod = date);
                  }
                },
              ),
              if (_paymentMethod == 'GCash') ...[
                const SizedBox(height: 16),
                if (_isUploading)
                  const Center(child: CircularProgressIndicator())
                else if (_receiptUrl != null && _fileBytes != null)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(_fileName ?? 'Receipt uploaded')),
                            IconButton(
                              icon: const Icon(Icons.visibility, size: 20),
                              onPressed: _showReceiptPreview,
                              tooltip: 'Preview Receipt',
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(() {
                                _receiptUrl = null;
                                _fileName = null;
                                _fileBytes = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _showReceiptPreview,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _fileBytes!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _pickAndUploadReceipt,
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload Receipt'),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isProcessing ? null : _recordPayment,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Payment'),
        ),
      ],
    );
  }

  Widget _buildMethodButton(String method, IconData icon) {
    final isSelected = _paymentMethod == method;
    return ElevatedButton(
      onPressed: () => setState(() => _paymentMethod = method),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? Colors.blue.shade600 : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.grey.shade700,
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 4),
          Text(method),
        ],
      ),
    );
  }

  // In payment_dialog.dart, update _recordPayment method

  void _recordPayment() async {
    if (_paymentMethod == 'GCash' && _receiptUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload a receipt'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final amount =
        double.tryParse(_amountController.text) ?? widget.tenant.billing;
    final reference = 'INV-${DateTime.now().millisecondsSinceEpoch}';
    final receiptId = 'receipt_${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Prepare receipt data
      String receiptDataBase64 = '';
      if (_fileBytes != null) {
        receiptDataBase64 = base64Encode(_fileBytes!);
      }

      // 1. Save payment to payments collection
      await FirebaseFirestore.instance.collection('payments').add({
        'tenantId': widget.tenant.id,
        'tenantName': widget.tenant.name,
        'date': Timestamp.fromDate(DateTime.now()),
        'amount': amount,
        'receiptUrl': _receiptUrl ?? '',
        'receiptData': receiptDataBase64,
        'method': _paymentMethod,
        'period': Timestamp.fromDate(_selectedPeriod),
        'reference': reference,
        'isVerified': _paymentMethod == 'Cash',
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'recordedBy': 'Super Admin',
        'receiptId': receiptId,
      });

      // 2. Save receipt to tenant's subcollection
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(widget.tenant.id)
          .collection('receipts')
          .doc(receiptId)
          .set({
        'receiptId': receiptId,
        'paymentReference': reference,
        'amount': amount,
        'method': _paymentMethod,
        'receiptData': receiptDataBase64,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'verified': _paymentMethod == 'Cash',
      });

      // 3. Save receipt to Super Admin's collection
      await FirebaseFirestore.instance
          .collection('superAdmin')
          .doc('superadmin')
          .collection('receipts')
          .doc(receiptId)
          .set({
        'receiptId': receiptId,
        'tenantId': widget.tenant.id,
        'tenantName': widget.tenant.name,
        'amount': amount,
        'method': _paymentMethod,
        'reference': reference,
        'receiptData': receiptDataBase64,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'uploadedBy': 'Super Admin',
        'verified': _paymentMethod == 'Cash',
        'verifiedAt': _paymentMethod == 'Cash'
            ? Timestamp.fromDate(DateTime.now())
            : null,
        'verifiedBy': _paymentMethod == 'Cash' ? 'Super Admin' : null,
      });

      // 4. Save to super admin audit trail
      await FirebaseFirestore.instance.collection('superAdminAudit').add({
        'action': 'Payment Recorded',
        'tenantId': widget.tenant.id,
        'tenantName': widget.tenant.name,
        'amount': amount,
        'reference': reference,
        'receiptId': receiptId,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'recordedBy': 'Super Admin',
      });

      debugPrint('✅ Payment and receipt saved to all locations');

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Payment recorded!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
