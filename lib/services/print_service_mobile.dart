import '../models/tenant.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void printInvoicePlatform(String tenantName, PaymentRecord record) {
  // Mobile platform fallback: logs details (can be upgraded to mobile print channels later)
  print('Direct browser HTML vector printing is not available on mobile devices.');
}

void launchMailtoPlatform(String recipient, String subject, String body) {
  print('Direct mail client launcher not supported on mobile.');
}

void downloadFilePlatform(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(filePath)],
    text: 'MedStock Pro - Excel Export',
  );
}
