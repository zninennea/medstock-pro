  import 'package:flutter/material.dart';

  class Transaction {
    final String id;
    final String productId;
    final String productName;
    final String lotNumber;
    final TransactionType type;
    final int qty;
    final String reason;
    final String reference;
    final String staffId;
    final String staffName;
    final DateTime timestamp;
    final int balAfter;
    final String tenantId;
    final Map<String, dynamic> productDetails;

    Transaction({
      required this.id,
      required this.productId,
      required this.productName,
      required this.lotNumber,
      required this.type,
      required this.qty,
      required this.reason,
      required this.reference,
      required this.staffId,
      required this.staffName,
      required this.timestamp,
      required this.balAfter,
      required this.tenantId,
      required this.productDetails,
    });

    static String generateRefNumber(String type) {
      final prefix = type.toLowerCase() == 'in' ? 'IN' : 'OUT';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
      return 'TX-$prefix-$timestamp';
    }

    Map<String, dynamic> toJson() => {
          'id': id,
          'productId': productId,
          'productName': productName,
          'lotNumber': lotNumber,
          'type': type == TransactionType.stockIn ? 'in' : 'out',
          'qty': qty,
          'reason': reason,
          'reference': reference,
          'staffId': staffId,
          'staffName': staffName,
          'timestamp': timestamp.toIso8601String(),
          'balAfter': balAfter,
          'tenantId': tenantId,
          'productDetails': productDetails,
        };

    factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
          id: json['id'] ?? '',
          productId: json['productId'] ?? '',
          productName: json['productName'] ?? '',
          lotNumber: json['lotNumber'] ?? '',
          type: json['type'] == 'in'
              ? TransactionType.stockIn
              : TransactionType.stockOut,
          qty: json['qty'] ?? 0,
          reason: json['reason'] ?? '',
          reference: json['reference'] ?? '',
          staffId: json['staffId'] ?? 'demo_staff_id',
          staffName: json['staffName'] ?? '',
          timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
          balAfter: json['balAfter'] ?? 0,
          tenantId: json['tenantId'] ?? '',
          productDetails: json['productDetails'] ?? {},
        );
  }

  enum TransactionType {
    stockIn,
    stockOut,
  }

  extension TransactionTypeExtension on TransactionType {
    String get displayName =>
        this == TransactionType.stockIn ? 'Stock In' : 'Stock Out';
    Color get color =>
        this == TransactionType.stockIn ? Colors.green : Colors.red;

    List<String> get reasons {
      if (this == TransactionType.stockIn) {
        return [
          'Restock (Purchase)',
          'Return from Patient',
          'Donation Received',
          'Inventory Correction (+)',
          'Transfer In',
        ];
      } else {
        return [
          'Dispensed to Patient',
          'Damaged / Expired Removal',
          'Return to Supplier',
          'Inventory Correction (-)',
          'Transfer Out',
          'Sample/Demo Use',
        ];
      }
    }
  }
