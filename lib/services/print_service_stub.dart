import '../models/tenant.dart';

void printInvoicePlatform(String tenantName, PaymentRecord record) {
  throw UnsupportedError('Cannot print invoice on this platform');
}

void launchMailtoPlatform(String recipient, String subject, String body) {
  throw UnsupportedError('Cannot launch mailto on this platform');
}

void downloadFilePlatform(List<int> bytes, String fileName) {
  throw UnsupportedError('Cannot download files on this platform');
}
