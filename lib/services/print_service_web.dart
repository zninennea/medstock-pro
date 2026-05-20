import 'dart:html' as html;
import 'package:intl/intl.dart';
import '../models/tenant.dart';

void printInvoicePlatform(String tenantName, PaymentRecord record) {
  final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(record.date);
  final periodStr = '${record.period.year}-${record.period.month.toString().padLeft(2, '0')}';
  
  final invoiceHtml = """
<!DOCTYPE html>
<html>
<head>
  <title>MedStock Pro Invoice - ${record.reference}</title>
  <style>
    body {
      font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      margin: 40px;
      color: #333;
      background-color: #FAFAFA;
    }
    .invoice-container {
      max-width: 800px;
      margin: 0 auto;
      border: 1px solid #e0e0e0;
      background-color: #ffffff;
      padding: 40px;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.05);
      position: relative;
      overflow: hidden;
    }
    .invoice-container::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 6px;
      background: linear-gradient(90deg, #3F51B5 0%, #E91E63 100%);
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 2px solid #f5f5f5;
      padding-bottom: 24px;
      margin-bottom: 30px;
    }
    .logo {
      font-size: 26px;
      font-weight: 800;
      color: #1A237E;
      letter-spacing: -0.8px;
    }
    .logo span {
      background: linear-gradient(90deg, #3F51B5 0%, #E91E63 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .invoice-title {
      font-size: 24px;
      font-weight: 800;
      color: #1A237E;
      text-transform: uppercase;
      margin: 0;
      letter-spacing: 1px;
    }
    .meta-section {
      display: flex;
      justify-content: space-between;
      margin-bottom: 40px;
      line-height: 1.6;
    }
    .meta-box {
      flex: 1;
    }
    .meta-box h3 {
      margin: 0 0 10px 0;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 1px;
      color: #9E9E9E;
    }
    .meta-box p {
      margin: 0;
      font-weight: 600;
      color: #424242;
    }
    .table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 40px;
    }
    .table th {
      background-color: #F8F9FA;
      color: #1A237E;
      text-align: left;
      padding: 14px;
      font-weight: 700;
      font-size: 13px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      border-bottom: 2px solid #EEEEEE;
    }
    .table td {
      padding: 18px 14px;
      border-bottom: 1px solid #EEEEEE;
      color: #616161;
      font-size: 14px;
    }
    .total-row td {
      border-top: 2px solid #1A237E;
      font-weight: 800;
      font-size: 18px;
      color: #1A237E;
      text-align: right;
      padding-top: 20px;
    }
    .badge {
      display: inline-block;
      padding: 8px 16px;
      border-radius: 30px;
      font-size: 12px;
      font-weight: 700;
      letter-spacing: 0.5px;
      text-transform: uppercase;
    }
    .badge-paid {
      background-color: #E8F5E9;
      color: #2E7D32;
      border: 1px solid #A5D6A7;
    }
    .footer {
      text-align: center;
      margin-top: 60px;
      font-size: 12px;
      color: #9E9E9E;
      border-top: 1px solid #EEEEEE;
      padding-top: 24px;
      line-height: 1.5;
    }
    @media print {
      body {
        margin: 0;
        background-color: #ffffff;
      }
      .invoice-container {
        border: none;
        box-shadow: none;
        padding: 0;
        max-width: 100%;
      }
    }
  </style>
</head>
<body>
  <div class="invoice-container">
    <div class="header">
      <div>
        <div class="logo">MedStock<span>Pro</span></div>
        <p style="margin: 6px 0 0 0; font-size: 12px; color: #757575;">Ultimate Multi-Tenant Inventory Suite</p>
      </div>
      <div style="text-align: right;">
        <h1 class="invoice-title">OFFICIAL RECEIPT</h1>
        <p style="margin: 6px 0 0 0; font-family: monospace; color: #E91E63; font-weight: bold; font-size: 14px;">${record.reference}</p>
      </div>
    </div>
    
    <div class="meta-section">
      <div class="meta-box">
        <h3>Billed To</h3>
        <p style="font-size: 18px; color: #1A237E; margin-bottom: 4px;">$tenantName</p>
        <p style="font-weight: normal; color: #616161; margin: 0;">Subscription Service Customer</p>
      </div>
      <div class="meta-box" style="text-align: right; max-width: 300px;">
        <h3>Invoice Details</h3>
        <p style="margin-bottom: 4px;">Date: <span style="font-weight: normal; color: #616161;">$formattedDate</span></p>
        <p style="margin-bottom: 4px;">Method: <span style="font-weight: normal; color: #616161;">${record.method}</span></p>
        <p style="margin-bottom: 4px;">Period: <span style="font-weight: normal; color: #616161;">$periodStr</span></p>
      </div>
    </div>
    
    <table class="table">
      <thead>
        <tr>
          <th>Description</th>
          <th style="text-align: right;">Unit Price</th>
          <th style="text-align: right;">Qty</th>
          <th style="text-align: right;">Total</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>
            <strong style="color: #212121; font-size: 15px;">MedStock Pro Cloud Subscription</strong><br>
            <span style="font-size: 12px; color: #757575;">Full multi-tenant cloud workspace, real-time Firestore sync, interactive alerts, and premium report modules</span>
          </td>
          <td style="text-align: right; font-family: monospace;">₱${record.amount.toStringAsFixed(2)}</td>
          <td style="text-align: right;">1</td>
          <td style="text-align: right; font-family: monospace; font-weight: bold; color: #212121;">₱${record.amount.toStringAsFixed(2)}</td>
        </tr>
        <tr class="total-row">
          <td colspan="3" style="text-transform: uppercase; letter-spacing: 0.5px; font-size: 14px; color: #616161;">Grand Total Paid:</td>
          <td style="font-family: monospace;">₱${record.amount.toStringAsFixed(2)}</td>
        </tr>
      </tbody>
    </table>
    
    <div style="text-align: center; margin-bottom: 20px;">
      <span class="badge badge-paid">✓ Secure Payment Verified</span>
    </div>
    
    <div class="footer">
      <p>Thank you for choosing MedStock Pro! For queries or billing support, contact <strong>billing@medstock.pro</strong></p>
      <p style="font-size: 10px; color: #BDBDBD; margin-top: 12px;">Generated securely via MedStock Pro HTML-PDF Render Engine V2 (Direct Vector Browser Output)</p>
    </div>
  </div>
  
  <script>
    window.onload = function() {
      setTimeout(function() {
        window.print();
      }, 500);
    }
  </script>
</body>
</html>
""";

  final blob = html.Blob([invoiceHtml], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

void launchMailtoPlatform(String recipient, String subject, String body) {
  final encodedSubject = Uri.encodeComponent(subject);
  final encodedBody = Uri.encodeComponent(body);
  final mailtoUrl = 'mailto:$recipient?subject=$encodedSubject&body=$encodedBody';
  html.window.open(mailtoUrl, '_self');
}

void downloadFilePlatform(List<int> bytes, String fileName) {
  final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
