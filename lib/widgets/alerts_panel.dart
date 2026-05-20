// lib/widgets/alerts_panel.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertsPanel extends StatelessWidget {
  final String tenantId;
  final String userId;

  const AlertsPanel({
    super.key,
    required this.tenantId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('alerts')
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final alerts = snapshot.data!.docs;

        return Container(
          margin: const EdgeInsets.all(8),
          child: Column(
            children: alerts.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final severity = data['severity'] ?? 'info';

              Color backgroundColor;
              switch (severity) {
                case 'critical':
                  backgroundColor = Colors.red.shade50;
                  break;
                case 'warning':
                  backgroundColor = Colors.orange.shade50;
                  break;
                default:
                  backgroundColor = Colors.blue.shade50;
              }

              return Card(
                color: backgroundColor,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    data['type'] == 'low_stock'
                        ? Icons.inventory
                        : data['type'] == 'expiring'
                            ? Icons.calendar_today
                            : Icons.payment,
                    color: severity == 'critical' ? Colors.red : Colors.orange,
                  ),
                  title: Text(
                    data['message'],
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('tenants')
                          .doc(tenantId)
                          .collection('alerts')
                          .doc(doc.id)
                          .update({
                        'read': true,
                        'readAt': FieldValue.serverTimestamp(),
                        'readBy': FieldValue.arrayUnion([userId]),
                      });
                    },
                  ),
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('tenants')
                        .doc(tenantId)
                        .collection('alerts')
                        .doc(doc.id)
                        .update({
                      'read': true,
                      'readAt': FieldValue.serverTimestamp(),
                      'readBy': FieldValue.arrayUnion([userId]),
                    });
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
