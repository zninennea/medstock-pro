// lib/screens/staff_management_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../config/api_config.dart';

class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final _staffEmailController = TextEditingController();
  final _staffNameController = TextEditingController();
  final Map<String, TextEditingController> _passwordControllers = {};
  final Map<String, bool> _passwordVisible = {};

  bool _isApiServerRunning = true;
  bool _isLoading = false;

  TextEditingController _passwordControllerFor(String email) {
    return _passwordControllers.putIfAbsent(
      email,
      () => TextEditingController(),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkApiServerStatus();
  }

  @override
  void dispose() {
    _staffEmailController.dispose();
    _staffNameController.dispose();
    for (final controller in _passwordControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _checkApiServerStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse(ApiConfig.statusEndpoint),
          )
          .timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _isApiServerRunning = response.statusCode == 200;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApiServerRunning = false;
        });
      }
      debugPrint('⚠️ API server status check failed: $e');
    }
  }

  void _showMessage(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _createStaffAccount(AuthProvider authProvider) async {
    final email = _staffEmailController.text.trim();
    final name = _staffNameController.text.trim();

    if (email.isEmpty || name.isEmpty) {
      _showMessage('Please enter both staff email and name.', success: false);
      return;
    }

    if (!email.contains('@')) {
      _showMessage('Please enter a valid staff email address.', success: false);
      return;
    }

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      _showMessage('Sign in again before creating staff accounts.',
          success: false);
      return;
    }

    final tenantId = currentUser.tenantId;
    if (tenantId == null) {
      _showMessage('Unable to determine tenant. Sign out and sign in again.',
          success: false);
      return;
    }

    setState(() => _isLoading = true);

    final success = await authProvider.createStaffAccount(
      adminEmail: currentUser.email,
      staffEmail: email,
      staffName: name,
      tenantId: tenantId,
    );

    setState(() => _isLoading = false);

    if (success) {
      _staffEmailController.clear();
      _staffNameController.clear();
      _showMessage(
          '✅ Staff account created successfully! Default password: staff123',
          success: true);
      setState(() {});
    } else {
      _showMessage(
          '❌ Unable to create staff account. Email may already exist or you lack permissions.',
          success: false);
    }
  }

  Future<void> _setStaffPassword(
    AuthProvider authProvider,
    String staffEmail,
  ) async {
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      _showMessage('Sign in again to set staff passwords.', success: false);
      return;
    }

    final controller = _passwordControllerFor(staffEmail);
    final password = controller.text.trim();

    if (password.isEmpty) {
      _showMessage('Enter a password to set for this staff account.',
          success: false);
      return;
    }

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters long.',
          success: false);
      return;
    }

    if (!_isApiServerRunning) {
      _showMessage(
        '❌ Admin API server is not running.\n\n'
        'To start the server:\n'
        '1. Open a terminal in the admin_tool folder\n'
        '2. Run: node server.js\n'
        '3. Keep it running while using the app',
        success: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await authProvider.setStaffPassword(
      adminEmail: currentUser.email,
      staffEmail: staffEmail,
      password: password,
    );

    setState(() => _isLoading = false);

    if (result == StaffPasswordResult.updated) {
      controller.clear();
      _showMessage(
          '✅ Password changed successfully for $staffEmail! The staff can now login with the new password.',
          success: true);
      setState(() {});
      return;
    }

    if (result == StaffPasswordResult.resetEmailSent) {
      controller.clear();
      _showMessage(
        '📧 A password reset email has been sent to $staffEmail.\n\n'
        'The staff member needs to:\n'
        '1. Check their email inbox\n'
        '2. Click the "Reset Password" link\n'
        '3. Enter the password you provided: "$password"\n\n'
        'They can then log in with their email and this password.',
        success: true,
      );
      return;
    }

    if (result == StaffPasswordResult.unauthorized) {
      _showMessage(
          '❌ Unable to update password. Ensure the account is a tenant staff account.',
          success: false);
      return;
    }

    _showMessage('❌ Unable to update password. Please try again.',
        success: false);
  }

  Future<void> _confirmDeleteStaff(
      AuthProvider authProvider, String staffEmail) async {
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      _showMessage('Sign in again to remove staff accounts.', success: false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove Staff Account'),
          content: Text(
              'Are you sure you want to remove $staffEmail from this tenant?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final success = await authProvider.deleteStaffAccount(
      adminEmail: currentUser.email,
      staffEmail: staffEmail,
    );

    setState(() => _isLoading = false);

    if (success) {
      _passwordControllers.remove(staffEmail)?.dispose();
      _showMessage('✅ Staff account removed successfully.');
      setState(() {});
    } else {
      _showMessage('❌ Failed to remove staff account.', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;
    final tenantId = currentUser?.tenantId?.toLowerCase().trim();
    final isAdmin = authProvider.isAdmin;

    if (!isAdmin || tenantId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Staff management is available only for tenant admins.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final staffAccounts = authProvider.accounts
        .where((account) =>
            account.role == UserRole.staff &&
            account.tenantId?.toLowerCase().trim() == tenantId)
        .toList();

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // API Server Status Warning
              if (!_isApiServerRunning)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Admin API Server is not running!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Password changes will not work. Start the server with: cd admin_tool && node server.js',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _checkApiServerStatus,
                        tooltip: 'Check Again',
                      ),
                    ],
                  ),
                ),

              const Text(
                'Staff Management',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create staff accounts and manage passwords for your tenant team.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Create Staff Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Staff Account',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _staffEmailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: 'Staff Email',
                          hintText: 'staff@example.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.email),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _staffNameController,
                        decoration: InputDecoration(
                          labelText: 'Staff Name',
                          hintText: 'Full Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () => _createStaffAccount(authProvider),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add),
                          label: const Text('Create Staff Account'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Staff List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Staff Accounts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (staffAccounts.isNotEmpty)
                    Text(
                      '${staffAccounts.length} staff members',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Staff List
              if (staffAccounts.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No staff accounts found',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Create your first staff account using the form above',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...staffAccounts.map((staff) {
                  final controller = _passwordControllerFor(staff.email);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Center(
                                  child: Text(
                                    staff.name.isNotEmpty
                                        ? staff.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      staff.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      staff.email,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // REMOVED: Password status indicator since passwords are not stored in Firestore
                              // Passwords are managed by Firebase Auth only
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller,
                            obscureText:
                                !(_passwordVisible[staff.email] ?? false),
                            decoration: InputDecoration(
                              labelText: 'Set New Password',
                              hintText: 'Enter new password (min 6 characters)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  (_passwordVisible[staff.email] ?? false)
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _passwordVisible[staff.email] =
                                        !(_passwordVisible[staff.email] ??
                                            false);
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _setStaffPassword(
                                          authProvider, staff.email),
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.save),
                                  label: const Text('Set/Change Password'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _confirmDeleteStaff(
                                          authProvider, staff.email),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Remove Staff'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    foregroundColor: Colors.red,
                                    side:
                                        BorderSide(color: Colors.red.shade300),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Passwords are securely managed by Firebase Authentication and are not stored in the database.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}
