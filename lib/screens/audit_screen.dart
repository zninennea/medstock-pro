// lib/screens/audit_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../models/user.dart';

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tenantProvider = Provider.of<TenantProvider>(context);
    final tenant =
        tenantProvider.getCurrentTenant(authProvider.currentTenantId!);

    if (tenant == null) {
      return const Center(child: Text('No tenant data'));
    }

    final auditEntries = tenant.auditTrail;

    if (auditEntries.isEmpty) {
      return const Center(child: Text('No audit records'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: auditEntries.length,
      itemBuilder: (context, index) {
        final entry = auditEntries[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.history, color: Colors.blue.shade700),
            ),
            title: Text(entry.action,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.details),
                const SizedBox(height: 4),
                Text(
                  'By: ${entry.user} (${_getRoleDisplayName(entry.role)})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            trailing: Text(
              _formatDateTime(entry.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
    }
  }
}
