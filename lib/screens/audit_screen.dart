// lib/screens/audit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tenantId = authProvider.currentTenantId;

    if (tenantId == null) {
      return const Center(child: Text('No tenant data'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('audit')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No audit records found'),
                SizedBox(height: 8),
                Text(
                    'Audit entries will appear when transactions are recorded'),
              ],
            ),
          );
        }

        final auditEntries = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: auditEntries.length,
          itemBuilder: (context, index) {
            final doc = auditEntries[index];
            final data = doc.data() as Map<String, dynamic>;

            // Handle different timestamp formats
            DateTime timestamp;
            if (data['timestamp'] is Timestamp) {
              timestamp = (data['timestamp'] as Timestamp).toDate();
            } else if (data['timestamp'] is String) {
              timestamp = DateTime.parse(data['timestamp']);
            } else {
              timestamp = DateTime.now();
            }

            final action = data['action'] ?? 'Action';
            final details = data['details'] ?? '';
            final user = data['user'] ?? 'Unknown';
            final role = data['role'] ?? 'staff';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(Icons.history, color: Colors.blue.shade700),
                ),
                title: Text(
                  action,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(details),
                    const SizedBox(height: 4),
                    Text(
                      'By: $user (${_getRoleDisplayName(role)})',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                trailing: Text(
                  _formatDateTime(timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'superAdmin':
        return 'Super Admin';
      case 'admin':
        return 'Admin';
      default:
        return 'Staff';
    }
  }
}
