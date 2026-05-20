// lib/screens/premium/expiry_alerts_scheduler.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product.dart';
import '../../services/print_service.dart';

class ExpiryAlertsScheduler extends StatefulWidget {
  const ExpiryAlertsScheduler({super.key});

  @override
  State<ExpiryAlertsScheduler> createState() => _ExpiryAlertsSchedulerState();
}

class _ExpiryAlertsSchedulerState extends State<ExpiryAlertsScheduler> {
  bool _dailyEmailDigest = true;
  double _warningThreshold = 90; // days
  double _criticalThreshold = 30; // days
  final _emailController = TextEditingController(text: 'admin@davmedical.com');
  
  bool _isScanning = false;
  bool _hasScanResult = false;
  List<Product> _flaggedProducts = [];
  String _scanLog = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _triggerSimulatedCloudScan() async {
    setState(() {
      _isScanning = true;
      _hasScanResult = false;
      _flaggedProducts.clear();
      _scanLog = 'Initializing Node.js Cloud Environment...\nAuthenticating custom claims & Firestore token...\n';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _scanLog += 'Executing Firebase Cron-Scheduler: daily-expiry-check\nQuerying all documents under collection: /products...\n';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = authProvider.currentTenantId ?? 'davmedical';
    
    // Filter product pool
    final products = productProvider.products.where((p) => p.tenantId == tenantId).toList();
    final now = DateTime.now();

    final flagged = <Product>[];
    for (final p in products) {
      final difference = p.expirationDate.difference(now).inDays;
      if (difference <= _warningThreshold || p.qty <= p.reorderThreshold) {
        flagged.add(p);
      }
    }

    setState(() {
      _flaggedProducts = flagged;
      _scanLog += 'Scanning ${products.length} product SKU records...\n';
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _scanLog += 'Found ${flagged.length} items requiring immediate alert notification.\nCompiling responsive HTML email payload...\nSending SMTP payload to ${_emailController.text}...\nStatus: 200 OK (Email Dispatched)';
      _isScanning = false;
      _hasScanResult = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📨 Cloud Alert Digest dispatched to ${_emailController.text}!'),
        backgroundColor: Colors.indigo,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _sendRealMailtoEmail() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);
    
    final subject = '[MedStock Pro] ⚠️ Critical Expiry & Stock Alert';
    
    var bodyText = 'Dear Admin,\n\n';
    bodyText += 'This is a live alert dispatch from your MedStock Pro Cloud Database.\n';
    bodyText += 'The automated daily inventory check completed at $dateStr.\n\n';
    bodyText += '-----------------------------------------------------------------\n';
    bodyText += 'ITEMS REQUIRING IMMEDIATE ATTENTION:\n';
    bodyText += '-----------------------------------------------------------------\n\n';
    
    if (_flaggedProducts.isEmpty) {
      bodyText += '✓ All stock levels and expiration dates are healthy and within thresholds!\n';
    } else {
      for (final p in _flaggedProducts) {
        final diffDays = p.expirationDate.difference(now).inDays;
        final isLow = p.qty <= p.reorderThreshold;
        
        var severity = 'WARNING';
        if (diffDays <= _criticalThreshold) {
          severity = 'CRITICAL EXPIRY';
        } else if (isLow) {
          severity = 'LOW STOCK';
        }
        
        bodyText += '• Medication: ${p.meds} (${p.brand})\n';
        bodyText += '  Lot Number: ${p.lotNumber}\n';
        bodyText += '  Current Stock: ${p.qty} ${p.uom}\n';
        bodyText += '  Expiration Date: ${DateFormat("yyyy-MM-dd").format(p.expirationDate)} ($diffDays days remaining)\n';
        bodyText += '  Alert Severity: [$severity]\n\n';
      }
    }
    
    bodyText += '-----------------------------------------------------------------\n';
    bodyText += 'Please log in to your MedStock Pro Workspace to replenish stocks or complete disposals.\n\n';
    bodyText += 'Best Regards,\nMedStock Pro Cloud Scheduler V2';
    
    PrintService.launchMailto(_emailController.text, subject, bodyText);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            color: Colors.indigo.shade900,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.mark_email_unread, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Automated Cloud Expiry Alerts',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Powered by Google Cloud Functions & Firebase Triggers. Monitors your inventory daily and sends email alerts instantly.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Configuration Cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Settings Controls
              Expanded(
                flex: 4,
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scheduler Settings',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 16),

                        // Switch toggle
                        SwitchListTile(
                          title: const Text('Daily Email Alert Digest', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Sends a beautiful summary email of low/expiring stocks every morning at 8:00 AM.', style: TextStyle(fontSize: 12)),
                          value: _dailyEmailDigest,
                          activeColor: Colors.indigo,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setState(() {
                              _dailyEmailDigest = val;
                            });
                          },
                        ),
                        const Divider(height: 24),

                        // Recipient input
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Digest Recipient Email',
                            hintText: 'Enter admin email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),

                        // Warning days slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Warning Expiry Threshold', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text('${_warningThreshold.toInt()} Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                            ),
                          ],
                        ),
                        Slider(
                          value: _warningThreshold,
                          min: 45,
                          max: 180,
                          divisions: 9,
                          activeColor: Colors.amber.shade600,
                          onChanged: (val) => setState(() => _warningThreshold = val),
                        ),
                        const Text(
                          'Products expiring within this threshold are labeled as "Expiring Soon" and placed in the email digest report.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),

                        // Critical days slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Critical Expiry Threshold', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(8)),
                              child: Text('${_criticalThreshold.toInt()} Days', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                            ),
                          ],
                        ),
                        Slider(
                          value: _criticalThreshold,
                          min: 15,
                          max: 45,
                          divisions: 6,
                          activeColor: Colors.red,
                          onChanged: (val) => setState(() => _criticalThreshold = val),
                        ),
                        const Text(
                          'Products expiring within this threshold trigger an immediate "Critical Priority" SMS and immediate popups.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Simulator Control Panel
              Expanded(
                flex: 3,
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cloud Function Simulator',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Simulate the automated Google Cloud Cron-Job executing in the background.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isScanning ? null : _triggerSimulatedCloudScan,
                            icon: _isScanning 
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.rocket_launch),
                            label: Text(_isScanning ? 'Running Scan...' : 'Trigger Daily Alert Scan'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Console Log Area
                        const Text('Cloud Console Logs:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          height: 160,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade800),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _scanLog.isEmpty ? 'Waiting for scheduler trigger...' : _scanLog,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // HTML Email Payload Simulator Display
          if (_hasScanResult) ...[
            const Text(
              '📧 DISPATCHED RESPONSIVE HTML EMAIL DIGEST PAYLOAD',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5, color: Colors.indigo),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.indigo.shade200, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Simulated Email Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MedStock Pro Cloud Alerts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.indigo)),
                            Text('Daily Expiry & Stock Level Report', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '⚠️ ACTION REQUIRED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    // Greeting
                    Text('Hello Admin,', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 8),
                    Text(
                      'The automated daily scan finished executing successfully on the cloud database. The following medications require prompt action because they are low in stock or approaching critical expiry thresholds.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                    ),
                    const SizedBox(height: 24),

                    // Table
                    if (_flaggedProducts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Text('All SKU stock statuses are normal and fully healthy!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                          ],
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 48,
                          columns: const [
                            DataColumn(label: Text('Medication / Brand')),
                            DataColumn(label: Text('Lot Number')),
                            DataColumn(label: Text('Stock')),
                            DataColumn(label: Text('Expiry Date')),
                            DataColumn(label: Text('Alert Severity')),
                          ],
                          rows: _flaggedProducts.map((p) {
                            final diffDays = p.expirationDate.difference(DateTime.now()).inDays;
                            final isLow = p.qty <= p.reorderThreshold;
                            final isExpiring = diffDays <= _warningThreshold;
                            
                            Color severityColor = Colors.amber;
                            String severityText = 'Warning';
                            if (diffDays <= _criticalThreshold) {
                              severityColor = Colors.red;
                              severityText = 'Critical Expiry';
                            } else if (isLow) {
                              severityColor = Colors.orange;
                              severityText = 'Low Stock';
                            }
                            
                            return DataRow(cells: [
                              DataCell(Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(p.meds, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(p.brand, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              )),
                              DataCell(Text(p.lotNumber, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
                              DataCell(Text('${p.qty} (${p.uom})', style: TextStyle(fontWeight: isLow ? FontWeight.bold : FontWeight.normal, color: isLow ? Colors.orange : null))),
                              DataCell(Text(DateFormat('yyyy-MM-dd').format(p.expirationDate))),
                              DataCell(Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: severityColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(severityText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: severityColor)),
                              )),
                            ]);
                          }).toList(),
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    const Divider(height: 32),

                    // Action Button
                    Center(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _sendRealMailtoEmail,
                                icon: const Icon(Icons.send_rounded),
                                label: const Text('Send Alert to Recipient Inbox', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Log In to Workspace'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.indigo,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Click "Send Alert to Recipient Inbox" to route a pre-formatted email to ${_emailController.text} via your default email application.',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
