import 'product.dart';

class TransactionItem {
  Product? product;
  int qty;
  String reason;
  String? lotNumber;
  String? details;
  int? currentStock;
  String? expiry;
  String? uom;
  String? meds;

  TransactionItem({
    this.product,
    this.qty = 1,
    this.reason = '',
    this.lotNumber,
    this.details,
    this.currentStock,
    this.expiry,
    this.uom,
    this.meds,
  });

  void updateFromProduct(Product p) {
    product = p;
    lotNumber = p.lotNumber;
    details = '${p.meds} | ${p.brand} | Stock: ${p.qty}';
    currentStock = p.qty;
    expiry = p.expirationDate.toIso8601String().split('T')[0];
    uom = p.uom;
    meds = p.meds;
  }

  bool get isValid => product != null && qty > 0;
}
