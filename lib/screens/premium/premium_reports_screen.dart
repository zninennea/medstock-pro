// lib/screens/premium/premium_reports_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../models/product.dart';
import '../../services/print_service.dart';
import '../../providers/product_provider.dart';

class PremiumReportsScreen extends StatefulWidget {
  const PremiumReportsScreen({super.key});

  @override
  State<PremiumReportsScreen> createState() => _PremiumReportsScreenState();
}

class _PremiumReportsScreenState extends State<PremiumReportsScreen> {
  String _selectedReport = 'expiry';
  int _expiryDays = 30;
  List<Product> _expiryProducts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpiryReport();
    });
  }

  Future<void> _loadExpiryReport() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    if (authProvider.currentTenantId != null) {
      if (productProvider.products.isEmpty) {
        await productProvider.loadProducts(authProvider.currentTenantId!);
      }
      final now = DateTime.now();
      final cutoffDate = now.add(Duration(days: _expiryDays));
      _expiryProducts = productProvider.products
          .where((p) =>
              p.expirationDate.isAfter(now) &&
              p.expirationDate.isBefore(cutoffDate))
          .toList()
        ..sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      setState(() {});
    }
  }

  Future<void> _exportPriceList() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    if (authProvider.currentTenantId == null) return;

    if (productProvider.products.isEmpty) {
      await productProvider.loadProducts(authProvider.currentTenantId!);
    }

    final excel = Excel.createExcel();
    final sheet = excel['Price List'];

    // Headers
    sheet.appendRow([
      TextCellValue('Meds'),
      TextCellValue('Brand'),
      TextCellValue('UOM'),
      TextCellValue('SRP (₱)'),
      TextCellValue('Category'),
      TextCellValue('Lot Number'),
      TextCellValue('Quantity'),
    ]);

    // Data
    for (final product in productProvider.products) {
      sheet.appendRow([
        TextCellValue(product.meds),
        TextCellValue(product.brand),
        TextCellValue(product.uom),
        DoubleCellValue(product.srp),
        TextCellValue(product.category),
        TextCellValue(product.lotNumber),
        IntCellValue(product.qty),
      ]);
    }

    final excelBytes = excel.save();
    if (excelBytes == null) return;

    final fileName = 'price_list_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    PrintService.downloadFile(excelBytes, fileName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Price list exported successfully!')),
      );
    }
  }

  Future<void> _exportExpiryReport() async {
    if (_expiryProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No expiring products in the selected range to export!')),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Expiry Report'];

    // Headers
    sheet.appendRow([
      TextCellValue('Meds'),
      TextCellValue('Brand'),
      TextCellValue('Lot Number'),
      TextCellValue('UOM'),
      TextCellValue('SRP (₱)'),
      TextCellValue('Expiry Date'),
      TextCellValue('Days Left'),
      TextCellValue('Quantity'),
    ]);

    final now = DateTime.now();
    // Data
    for (final product in _expiryProducts) {
      final daysLeft = product.expirationDate.difference(now).inDays;
      sheet.appendRow([
        TextCellValue(product.meds),
        TextCellValue(product.brand),
        TextCellValue(product.lotNumber),
        TextCellValue(product.uom),
        DoubleCellValue(product.srp),
        TextCellValue(_formatDate(product.expirationDate)),
        IntCellValue(daysLeft),
        IntCellValue(product.qty),
      ]);
    }

    final excelBytes = excel.save();
    if (excelBytes == null) return;

    final fileName = 'expiry_report_${_expiryDays}days_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    PrintService.downloadFile(excelBytes, fileName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Expiry report ($_expiryDays days) downloaded successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Report Selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildReportButton(
                    'Expiry Report', 'expiry', Icons.calendar_today),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildReportButton(
                    'Price List', 'price', Icons.price_change),
              ),
            ],
          ),
        ),

        // Report Content
        Expanded(
          child: _selectedReport == 'expiry'
              ? _buildExpiryReport(isDark)
              : _buildPriceListExport(isDark),
        ),
      ],
    );
  }

  Widget _buildReportButton(String label, String reportId, IconData icon) {
    final isSelected = _selectedReport == reportId;
    return ElevatedButton(
      onPressed: () {
        setState(() => _selectedReport = reportId);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue.shade600 : null,
        foregroundColor: isSelected ? Colors.white : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildExpiryReport(bool isDark) {
    return Column(
      children: [
        // Days Filter
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildDaysButton('30 Days', 30),
              const SizedBox(width: 8),
              _buildDaysButton('60 Days', 60),
              const SizedBox(width: 8),
              _buildDaysButton('90 Days', 90),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _exportExpiryReport,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // Report Table
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Meds')),
                DataColumn(label: Text('Lot#')),
                DataColumn(label: Text('Expiry')),
                DataColumn(label: Text('Days Left')),
                DataColumn(label: Text('Qty')),
              ],
              rows: _expiryProducts.map((product) {
                final daysLeft =
                    product.expirationDate.difference(DateTime.now()).inDays;
                return DataRow(cells: [
                  DataCell(Text(product.meds)),
                  DataCell(Text(product.lotNumber)),
                  DataCell(Text(_formatDate(product.expirationDate))),
                  DataCell(Text(
                    '$daysLeft days',
                    style: TextStyle(
                        color: daysLeft <= 30 ? Colors.red : null,
                        fontWeight: FontWeight.bold),
                  )),
                  DataCell(Text(product.qty.toString())),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysButton(String label, int days) {
    final isSelected = _expiryDays == days;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _expiryDays = days;
            _loadExpiryReport();
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue.shade600 : null,
          foregroundColor: isSelected ? Colors.white : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildPriceListExport(bool isDark) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.file_download, size: 64, color: Colors.green.shade600),
              const SizedBox(height: 16),
              const Text(
                'Export Price List',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Export product list with Meds, Brand, UOM, and SRP',
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _exportPriceList,
                icon: const Icon(Icons.download),
                label: const Text('Export to Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
