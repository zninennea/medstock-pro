import '../models/tenant.dart';
import 'print_service_stub.dart'
    if (dart.library.html) 'print_service_web.dart'
    if (dart.library.io) 'print_service_mobile.dart';

class PrintService {
  static void printInvoice(String tenantName, PaymentRecord record) {
    printInvoicePlatform(tenantName, record);
  }

  static void launchMailto(String recipient, String subject, String body) {
    launchMailtoPlatform(recipient, subject, body);
  }

  static void downloadFile(List<int> bytes, String fileName) {
    downloadFilePlatform(bytes, fileName);
  }
}
