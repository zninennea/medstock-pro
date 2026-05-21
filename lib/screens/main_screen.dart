// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/product_provider.dart';
import '../models/tenant.dart';
import '../models/user.dart';
import 'dashboard_screen.dart';
import 'products_screen.dart';
import 'transaction_screen.dart';
import 'alerts_screen.dart';
import 'audit_screen.dart';
import 'reports_screen.dart';
import 'staff_management_screen.dart';
import 'super_admin_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _dataLoaded = false;

  final List<Map<String, dynamic>> _adminMenuItems = [
    {
      'icon': Icons.dashboard,
      'label': 'Dashboard',
      'screen': const DashboardScreen()
    },
    {
      'icon': Icons.inventory,
      'label': 'Products',
      'screen': const ProductsScreen()
    },
    {
      'icon': Icons.people,
      'label': 'Staff',
      'screen': const StaffManagementScreen()
    },
    {
      'icon': Icons.swap_horiz,
      'label': 'Record IN/OUT',
      'screen': const TransactionScreen()
    },
    {
      'icon': Icons.notifications,
      'label': 'Alerts',
      'screen': const AlertsScreen()
    },
    {
      'icon': Icons.history,
      'label': 'Audit Trail',
      'screen': const AuditScreen()
    },
    {
      'icon': Icons.analytics,
      'label': 'Reports',
      'screen': const ReportsScreen()
    },
  ];

  final List<Map<String, dynamic>> _staffMenuItems = [
    {
      'icon': Icons.dashboard,
      'label': 'Dashboard',
      'screen': const DashboardScreen()
    },
    {
      'icon': Icons.inventory,
      'label': 'Products',
      'screen': const ProductsScreen()
    },
    {
      'icon': Icons.swap_horiz,
      'label': 'Record IN/OUT',
      'screen': const TransactionScreen()
    },
    {
      'icon': Icons.notifications,
      'label': 'Alerts',
      'screen': const AlertsScreen()
    },
    {
      'icon': Icons.history,
      'label': 'Audit Trail',
      'screen': const AuditScreen()
    },
  ];

  final List<Map<String, dynamic>> _superAdminMenuItems = [
    {
      'icon': Icons.dashboard,
      'label': 'Platform Dashboard',
      'screen': const SuperAdminScreen()
    },
  ];

  List<Map<String, dynamic>> get _menuItems {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isSuperAdmin) return _superAdminMenuItems;
    if (authProvider.isAdmin) return _adminMenuItems;
    return _staffMenuItems;
  }

  String _getRoleDisplayName(UserRole? role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tenantProvider = Provider.of<TenantProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    final currentTenant = authProvider.currentTenantId != null
        ? tenantProvider.getCurrentTenant(authProvider.currentTenantId!)
        : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;
// Load data when user is logged in (runs after build is complete)
    // Load data only once when screen first appears
    if (!_dataLoaded && authProvider.isLoggedIn) {
      _dataLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (authProvider.currentTenantId != null) {
          productProvider.loadProducts(authProvider.currentTenantId!);
        }
        tenantProvider.refreshTenants();
      });
    }
    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_menuItems[_selectedIndex]['label'].toUpperCase(),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          elevation: 1,
          actions: [
            // Theme toggle
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, size: 20),
              onPressed: () => themeProvider.toggleTheme(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            // Change password (Admin only)
            if (authProvider.isAdmin || authProvider.isSuperAdmin)
              IconButton(
                icon: const Icon(Icons.lock_outline, size: 20),
                onPressed: () => _showChangePasswordDialog(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 8),
            // Logout
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red, size: 20),
              onPressed: () => authProvider.logout(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _menuItems[_selectedIndex]['screen'],
        bottomNavigationBar:
            _buildMobileBottomBar(authProvider, productProvider, isDark),
      );
    }

    // Desktop layout (existing code)
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarCollapsed ? 80 : 260,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                right: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.indigo.shade600
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.medication,
                            color: Colors.white, size: 22),
                      ),
                      if (!_isSidebarCollapsed) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getRoleDisplayName(
                                        authProvider.currentUser?.role)
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                currentTenant?.name ?? 'Platform Owner',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey.shade900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: Icon(_isSidebarCollapsed
                            ? Icons.chevron_right
                            : Icons.chevron_left),
                        onPressed: () => setState(
                            () => _isSidebarCollapsed = !_isSidebarCollapsed),
                        iconSize: 18,
                      ),
                    ],
                  ),
                ),
                // Navigation Menu
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final isSelected = _selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedIndex = index);
                              if (item['label'] == 'Products' &&
                                  authProvider.currentTenantId != null) {
                                productProvider.loadProducts(
                                    authProvider.currentTenantId!);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark
                                        ? Colors.blue.shade900
                                            .withValues(alpha: 0.3)
                                        : Colors.blue.shade50)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(item['icon'],
                                      size: 20,
                                      color: isSelected
                                          ? Colors.blue.shade600
                                          : (isDark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700)),
                                  if (!_isSidebarCollapsed) ...[
                                    const SizedBox(width: 12),
                                    Text(item['label'],
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.blue.shade600
                                              : (isDark
                                                  ? Colors.grey.shade300
                                                  : Colors.grey.shade800),
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        )),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Theme Toggle
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => themeProvider.toggleTheme(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(isDark ? Icons.light_mode : Icons.dark_mode,
                                size: 20,
                                color: isDark
                                    ? Colors.amber.shade400
                                    : Colors.grey.shade700),
                            if (!_isSidebarCollapsed) ...[
                              const SizedBox(width: 12),
                              Text(isDark ? 'Light Mode' : 'Dark Mode',
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade800)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Logout
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => authProvider.logout(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.logout,
                                size: 20, color: Colors.red),
                            if (!_isSidebarCollapsed) ...[
                              const SizedBox(width: 12),
                              const Text('Sign Out',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                // App Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                        bottom: BorderSide(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      if (!_isSidebarCollapsed)
                        IconButton(
                          icon: Icon(Icons.menu,
                              color:
                                  isDark ? Colors.white : Colors.grey.shade800),
                          onPressed: () => setState(
                              () => _isSidebarCollapsed = !_isSidebarCollapsed),
                        ),
                      const SizedBox(width: 8),
                      Text(_menuItems[_selectedIndex]['label'].toUpperCase(),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                            authProvider.isOnline ? Icons.wifi : Icons.wifi_off,
                            color: authProvider.isOnline
                                ? Colors.green
                                : Colors.orange),
                        onPressed: () => authProvider.toggleOnline(),
                      ),
                      const SizedBox(width: 8),
                      if (authProvider.isAdmin || authProvider.isSuperAdmin)
                        IconButton(
                          icon: const Icon(Icons.lock_outline),
                          onPressed: () => _showChangePasswordDialog(context),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: currentTenant?.tier == TenantTier.premium
                              ? (isDark
                                  ? Colors.indigo.shade900
                                  : Colors.indigo.shade100)
                              : (isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentTenant?.tier.displayName ?? 'SUPER ADMIN',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: currentTenant?.tier == TenantTier.premium
                                  ? (isDark
                                      ? Colors.indigo.shade300
                                      : Colors.indigo.shade800)
                                  : (isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Offline Banner
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: authProvider.isOnline ? 0 : 36,
                  color: Colors.orange.shade800,
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: const SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                            'Offline Mode Active — Transactions queued locally.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                // Content Area
                Expanded(child: _menuItems[_selectedIndex]['screen']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar(
      AuthProvider authProvider, ProductProvider productProvider, bool isDark) {
    final items = _menuItems;

    // For Super Admin with only 1 item, use a custom bottom bar with logout
    if (items.length == 1) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
              top: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Dashboard button
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _selectedIndex = 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(items[0]['icon'],
                        color: Colors.blue.shade600, size: 24),
                    const SizedBox(height: 4),
                    Text(items[0]['label'],
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            // Logout button
            Expanded(
              child: InkWell(
                onTap: () => authProvider.logout(),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 24),
                    SizedBox(height: 4),
                    Text('Logout',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.red)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // For Admin and Staff with multiple items
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue.shade600,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        setState(() => _selectedIndex = index);
        if (items[index]['label'] == 'Products' &&
            authProvider.currentTenantId != null) {
          productProvider.loadProducts(authProvider.currentTenantId!);
        }
      },
      items: items.map((item) {
        return BottomNavigationBarItem(
          icon: Icon(item['icon'], size: 22),
          label: item['label'],
        );
      }).toList(),
    );
  }

  // lib/screens/main_screen.dart

  // lib/screens/main_screen.dart

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in first')),
        );
      }
      return;
    }

    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isLoading = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isLoading,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                    hintText: 'Enter your current password',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    hintText: 'Minimum 6 characters',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                    hintText: 'Re-enter new password',
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final oldP = oldController.text.trim();
                        final newP = newController.text.trim();
                        final confirmP = confirmController.text.trim();

                        // Validation
                        if (oldP.isEmpty || newP.isEmpty || confirmP.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Please fill in all fields')),
                          );
                          return;
                        }

                        if (newP.length < 6) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'New password must be at least 6 characters')),
                          );
                          return;
                        }

                        if (newP != confirmP) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('New passwords do not match')),
                          );
                          return;
                        }

                        if (oldP == newP) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'New password must be different from current password')),
                          );
                          return;
                        }

                        // Show loading
                        setState(() {
                          isLoading = true;
                        });

                        final success = await authProvider.changePassword(
                          currentUser.email,
                          oldP,
                          newP,
                        );

                        setState(() {
                          isLoading = false;
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx, success);
                        }
                      },
                child: const Text('Change Password'),
              ),
            ],
          );
        },
      ),
    );

    if (mounted) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Password changed successfully! Please use your new password next login.'),
            backgroundColor: Colors.green,
          ),
        );
        oldController.clear();
        newController.clear();
        confirmController.clear();
      } else if (result == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '❌ Failed to change password. Check your current password.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
