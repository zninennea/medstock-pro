// lib/widgets/billing_card.dart
import 'package:flutter/material.dart';
import '../models/tenant.dart';

class BillingCard extends StatelessWidget {
  final Tenant tenant;

  const BillingCard({super.key, required this.tenant});

  @override
  Widget build(BuildContext context) {
    final paymentStatus = tenant.paymentStatus;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Billing Information',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current Plan',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600)),
                          Text(tenant.tier.displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Billing',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600)),
                          Text('₱${tenant.billing}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Status',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade600)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: paymentStatus.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              paymentStatus.displayName,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: paymentStatus.color,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
