// lib/models/tenant.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'product.dart';
import 'transaction.dart';
import 'user.dart';

class Tenant {
  final String id;
  String name;
  String address;
  TenantTier tier;
  double billing;
  String email;
  bool paid;
  bool suspended;
  List<Product> products;
  List<Transaction> transactions;
  List<AuditEntry> auditTrail;
  List<PaymentRecord> paymentHistory;
  TenantSettings settings;

  Tenant({
    required this.id,
    required this.name,
    required this.address,
    required this.tier,
    required this.billing,
    required this.email,
    this.paid = false,
    this.suspended = false,
    required this.products,
    required this.transactions,
    required this.auditTrail,
    required this.paymentHistory,
    required this.settings,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    final tierString = (json['tier'] as String?)?.toLowerCase() ?? 'basic';
    return Tenant(
      id: (json['id'] ?? json['tenantId'] ?? '') as String,
      name: (json['name'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      tier: tierString == 'premium' ? TenantTier.premium : TenantTier.basic,
      billing: ((json['billing'] ?? 0) as num).toDouble(),
      email: (json['email'] as String?) ?? '',
      paid: json['paid'] == true,
      suspended: json['suspended'] == true,
      products: [],
      transactions: [],
      auditTrail: [],
      paymentHistory: [],
      settings: TenantSettings(),
    );
  }

  double get totalInventoryValue {
    return products.fold(0, (sum, p) => sum + (p.qty * p.cost));
  }

  int get alertCount {
    return products
        .where((p) => p.isLowStock || p.isExpired || p.isExpiringSoon)
        .length;
  }

  PaymentStatus get paymentStatus {
    if (suspended) {
      return PaymentStatus.overdue;
    }
    if (paid) {
      return PaymentStatus.paid;
    }

    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;
    final hasPaidLastMonth = paymentHistory.any((p) =>
        p.period.month == currentMonth - 1 && p.period.year == currentYear);

    if (hasPaidLastMonth) return PaymentStatus.pending;
    return PaymentStatus.overdue;
  }
}

enum TenantTier {
  basic,
  premium,
}

extension TenantTierExtension on TenantTier {
  String get displayName => this == TenantTier.basic ? 'Basic' : 'Premium';
  double get price => this == TenantTier.basic ? 4500 : 12500;
  bool get hasAdvancedReports => this == TenantTier.premium;
  bool get hasAnalyticsDashboard => this == TenantTier.premium;
  bool get hasEmailAlerts => this == TenantTier.premium;
  bool get hasExcelExport => this == TenantTier.premium;
}

enum PaymentStatus {
  paid,
  pending,
  overdue,
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.overdue:
        return 'Overdue';
    }
  }

  Color get color {
    switch (this) {
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.overdue:
        return Colors.red;
    }
  }
}

class PaymentRecord {
  final DateTime date;
  final double amount;
  final String receiptUrl;
  final String method;
  final DateTime period;
  final String reference;
  final Uint8List? receiptBytes;
  bool isVerified;

  PaymentRecord({
    required this.date,
    required this.amount,
    required this.receiptUrl,
    required this.method,
    required this.period,
    required this.reference,
    this.receiptBytes,
    this.isVerified = false,
  });
}

class AuditEntry {
  final DateTime timestamp;
  final String action;
  final String details;
  final String user;
  final UserRole role;

  AuditEntry({
    required this.timestamp,
    required this.action,
    required this.details,
    required this.user,
    required this.role,
  });
}

class TenantSettings {
  bool emailAlerts;
  bool lowStockAlerts;
  bool expiryAlerts;

  TenantSettings({
    this.emailAlerts = false,
    this.lowStockAlerts = true,
    this.expiryAlerts = true,
  });
}
