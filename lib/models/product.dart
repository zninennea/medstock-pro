// lib/models/product.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  String id;
  String tenantId;
  String meds;
  String brand;
  String category;
  String lotNumber;
  int qty;
  String uom;
  double cost;
  double srp;
  DateTime expirationDate;
  int reorderThreshold;
  String supplier;
  String? imageUrl;

  Product({
    required this.id,
    required this.tenantId,
    required this.meds,
    required this.brand,
    required this.category,
    required this.lotNumber,
    required this.qty,
    required this.uom,
    required this.cost,
    required this.srp,
    required this.expirationDate,
    required this.reorderThreshold,
    required this.supplier,
    this.imageUrl,
  });

  // Add copyWith method
  Product copyWith({
    String? id,
    String? tenantId,
    String? meds,
    String? brand,
    String? category,
    String? lotNumber,
    int? qty,
    String? uom,
    double? cost,
    double? srp,
    DateTime? expirationDate,
    int? reorderThreshold,
    String? supplier,
    String? imageUrl,
  }) {
    return Product(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      meds: meds ?? this.meds,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      lotNumber: lotNumber ?? this.lotNumber,
      qty: qty ?? this.qty,
      uom: uom ?? this.uom,
      cost: cost ?? this.cost,
      srp: srp ?? this.srp,
      expirationDate: expirationDate ?? this.expirationDate,
      reorderThreshold: reorderThreshold ?? this.reorderThreshold,
      supplier: supplier ?? this.supplier,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'meds': meds,
        'brand': brand,
        'category': category,
        'lotNumber': lotNumber,
        'qty': qty,
        'uom': uom,
        'cost': cost,
        'srp': srp,
        'expirationDate': Timestamp.fromDate(expirationDate),
        'reorderThreshold': reorderThreshold,
        'supplier': supplier,
        'imageUrl': imageUrl,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    DateTime expiryDate;
    if (json['expirationDate'] is Timestamp) {
      expiryDate = (json['expirationDate'] as Timestamp).toDate();
    } else if (json['expirationDate'] is String) {
      expiryDate = DateTime.parse(json['expirationDate']);
    } else {
      expiryDate = DateTime.now();
    }

    return Product(
      id: json['id'] ?? '',
      tenantId: json['tenantId'] ?? '',
      meds: json['meds'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? '',
      lotNumber: json['lotNumber'] ?? '',
      qty: json['qty'] ?? 0,
      uom: json['uom'] ?? 'Piece',
      cost: (json['cost'] ?? 0).toDouble(),
      srp: (json['srp'] ?? 0).toDouble(),
      expirationDate: expiryDate,
      reorderThreshold: json['reorderThreshold'] ?? 10,
      supplier: json['supplier'] ?? '',
      imageUrl: json['imageUrl'],
    );
  }

  bool get isExpired => expirationDate.isBefore(DateTime.now());

  bool get isExpiringSoon {
    final daysLeft = expirationDate.difference(DateTime.now()).inDays;
    return daysLeft <= 90 && daysLeft > 0;
  }

  bool get isLowStock => qty <= reorderThreshold;

  String get stockStatus {
    if (isExpired && isLowStock) return 'expired_low';
    if (isExpired) return 'expired';
    if (isExpiringSoon && isLowStock) return 'critical';
    if (isExpiringSoon) return 'expiring';
    if (isLowStock) return 'low';
    return 'ok';
  }

  String get stockStatusText {
    switch (stockStatus) {
      case 'expired_low':
        return 'Expired + Low Stock';
      case 'critical':
        return 'Critical (Low + Expiring)';
      case 'expired':
        return 'Expired';
      case 'expiring':
        return 'Expiring Soon';
      case 'low':
        return 'Low Stock';
      default:
        return 'In Stock';
    }
  }

  Color get stockStatusColor {
    switch (stockStatus) {
      case 'expired_low':
        return Colors.red.shade900;
      case 'critical':
        return Colors.red.shade700;
      case 'expired':
        return Colors.red;
      case 'expiring':
        return Colors.orange;
      case 'low':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}
