// lib/providers/auth_provider.dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../services/firestore_service.dart';
import '../config/api_config.dart';

// Login result enum for better error handling
enum LoginResult {
  success,
  invalidCredentials,
  tenantSuspended,
  tenantNotFound,
  error,
}

// Login response class with message
class LoginResponse {
  final bool success;
  final String message;
  final LoginResult result;

  LoginResponse({
    required this.success,
    required this.message,
    required this.result,
  });
}

class AuthProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final FirestoreService _firestoreService = FirestoreService();
  final fb_auth.FirebaseAuth _firebaseAuth = fb_auth.FirebaseAuth.instance;
  User? _currentUser;
  String? _currentTenantId;

  final Map<String, AuthAccount> _accounts = {
    'superadmin@medstock.pro': AuthAccount(
      email: 'superadmin@medstock.pro',
      password: 'super123',
      name: 'Super Admin',
      role: UserRole.superAdmin,
      tenantId: null,
      createdBy: 'system',
    ),
    'admin@davmedical.com': AuthAccount(
      email: 'admin@davmedical.com',
      password: 'admin123',
      name: 'Davao Medical Admin',
      role: UserRole.admin,
      tenantId: 'davmedical',
      createdBy: 'superadmin@medstock.pro',
    ),
    'admin@cebgeneral.com': AuthAccount(
      email: 'admin@cebgeneral.com',
      password: 'admin123',
      name: 'Cebu General Admin',
      role: UserRole.admin,
      tenantId: 'cebgeneral',
      createdBy: 'superadmin@medstock.pro',
    ),
    'maria.santos@davmedical.com': AuthAccount(
      email: 'maria.santos@davmedical.com',
      password: 'staff123',
      name: 'Maria Santos',
      role: UserRole.staff,
      tenantId: 'davmedical',
      createdBy: 'admin@davmedical.com',
    ),
    'jun.reyes@davmedical.com': AuthAccount(
      email: 'jun.reyes@davmedical.com',
      password: null,
      name: 'Jun Reyes',
      role: UserRole.staff,
      tenantId: 'davmedical',
      createdBy: 'admin@davmedical.com',
    ),
  };

  AuthProvider(this._prefs) {
    _loadSession();
    _loadAuthAccounts();
  }

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  void toggleOnline() {
    _isOnline = !_isOnline;
    notifyListeners();
  }

  User? get currentUser => _currentUser;
  String? get currentTenantId => _currentTenantId;
  bool get isLoggedIn => _currentUser != null;
  bool get isSuperAdmin => _currentUser?.role == UserRole.superAdmin;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  fb_auth.FirebaseAuth get firebaseAuth => _firebaseAuth;

  List<AuthAccount> get accounts => _accounts.values.toList();
  List<AuthAccount> get staffAccounts =>
      _accounts.values.where((a) => a.role == UserRole.staff).toList();

  void _loadSession() {
    final userJson = _prefs.getString('user');
    if (userJson != null) {
      try {
        final parsed = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(parsed);
        _currentTenantId = parsed['tenantId'] as String?;
      } catch (_) {
        _currentUser = null;
        _currentTenantId = null;
      }
    }
  }

  Future<void> _loadAuthAccounts() async {
    try {
      final remoteAccounts = await _firestoreService.getAllAuthAccounts();
      if (remoteAccounts.isNotEmpty) {
        final fallbackAccounts = Map<String, AuthAccount>.from(_accounts);
        _accounts
          ..clear()
          ..addEntries(remoteAccounts.map((data) {
            final account = AuthAccount.fromJson(data);
            if (account.password == null &&
                fallbackAccounts.containsKey(account.email)) {
              account.password = fallbackAccounts[account.email]!.password;
            }
            return MapEntry(account.email, account);
          }));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ AuthProvider failed to load remote auth accounts: $e');
    }
  }

  // Helper method to set custom claims via the local API
  Future<bool> _setCustomClaimsViaAPI({
    required String email,
    required String role,
    required String? tenantId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.setClaimsEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'role': role,
              'tenantId': tenantId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint(
            '✅ Custom claims set for $email: role=$role, tenantId=$tenantId');
        return true;
      } else {
        debugPrint('❌ Failed to set custom claims: ${data['error']}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error setting custom claims via API: $e');
      return false;
    }
  }

  // COMPLETE LOGIN METHOD WITH TENANT SUSPENSION CHECK
  Future<LoginResponse> login(String email, String password) async {
    final normalizedEmail = email.toLowerCase().trim();

    // First, try Firebase Auth sign in
    fb_auth.UserCredential? userCredential;
    try {
      userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      debugPrint('✅ Firebase Auth sign in successful for: $normalizedEmail');
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase Auth sign-in failed: ${e.code} - ${e.message}');

      // Check if user exists in our local accounts but not in Firebase
      final fallback = _accounts[normalizedEmail];
      if (fallback != null && fallback.password == password) {
        // Create the user in Firebase Auth
        try {
          userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
          debugPrint('✅ Created Firebase Auth user for: $normalizedEmail');
        } catch (createError) {
          debugPrint('❌ Failed to create user: $createError');
          return LoginResponse(
            success: false,
            message: 'Invalid email or password',
            result: LoginResult.invalidCredentials,
          );
        }
      } else {
        return LoginResponse(
          success: false,
          message: 'Invalid email or password',
          result: LoginResult.invalidCredentials,
        );
      }
    }

    if (userCredential == null || userCredential.user == null) {
      return LoginResponse(
        success: false,
        message: 'Invalid email or password',
        result: LoginResult.invalidCredentials,
      );
    }

    // Now get the user profile from Firestore or local accounts
    await _loadAuthAccounts();

    var account = _accounts[normalizedEmail];
    if (account == null) {
      // Try to get from Firestore
      final remoteData =
          await _firestoreService.getAuthAccount(normalizedEmail);
      if (remoteData != null) {
        account = AuthAccount.fromJson(remoteData);
        _accounts[normalizedEmail] = account;
      } else {
        // Create a basic account from Firebase user
        final idTokenResult = await userCredential.user!.getIdTokenResult();
        final claims = idTokenResult.claims;

        String role = 'staff';
        String? tenantId;

        if (claims != null) {
          role = claims['role'] ?? 'staff';
          tenantId = claims['tenantId'] as String?;
        }

        UserRole userRole;
        switch (role) {
          case 'superAdmin':
            userRole = UserRole.superAdmin;
            break;
          case 'admin':
            userRole = UserRole.admin;
            break;
          default:
            userRole = UserRole.staff;
        }

        account = AuthAccount(
          email: normalizedEmail,
          password: password,
          name: normalizedEmail.split('@').first,
          role: userRole,
          tenantId: tenantId,
          createdBy: 'system',
        );
        _accounts[normalizedEmail] = account;

        // Save to Firestore
        await _firestoreService.addAuthAccount(
            normalizedEmail, account.toJson());
      }
    }

    // ============================================================
    // CHECK IF TENANT IS SUSPENDED - RETURN SPECIFIC MESSAGE
    // ============================================================
    if (account.tenantId != null && account.role != UserRole.superAdmin) {
      try {
        final tenant = await _firestoreService.getTenant(account.tenantId!);
        if (tenant != null && tenant['suspended'] == true) {
          debugPrint(
              '❌ Login blocked: Tenant ${account.tenantId} is suspended');
          await _firebaseAuth.signOut();
          return LoginResponse(
            success: false,
            message:
                '⚠️ Your account has been suspended.\n\nPlease contact your system administrator or support team to resolve this issue.',
            result: LoginResult.tenantSuspended,
          );
        }
      } catch (e) {
        debugPrint('Error checking tenant status: $e');
      }
    }
    // ============================================================

    // Check and set custom claims if not present
    try {
      final idTokenResult = await userCredential.user!.getIdTokenResult();
      final claims = idTokenResult.claims;

      if (claims == null ||
          claims['role'] != account.role.name ||
          claims['tenantId'] != account.tenantId) {
        final claimsSet = await _setCustomClaimsViaAPI(
          email: normalizedEmail,
          role: account.role.name,
          tenantId: account.tenantId,
        );

        if (claimsSet) {
          await userCredential.user!.getIdToken(true);
          debugPrint(
              '✅ Custom claims set and token refreshed for: $normalizedEmail');
        }
      } else {
        debugPrint('✅ User already has correct custom claims');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking/setting custom claims: $e');
    }

    _currentUser = User(
      id: userCredential.user!.uid,
      name: account.name,
      email: account.email,
      role: account.role,
      tenantId: account.tenantId,
    );
    _currentTenantId = account.tenantId;

    await _prefs.setString('user', jsonEncode(_currentUser!.toJson()));
    if (_currentTenantId != null) {
      await _prefs.setString('currentTenant', _currentTenantId!);
    }

    notifyListeners();
    debugPrint(
        '✅ Login successful for: $normalizedEmail (Role: ${account.role.name})');

    return LoginResponse(
      success: true,
      message: 'Login successful',
      result: LoginResult.success,
    );
  }

  // lib/providers/auth_provider.dart

  Future<bool> changePassword(
    String email,
    String oldPassword,
    String newPassword,
  ) async {
    final normalizedEmail = email.toLowerCase().trim();
    final currentUser = _firebaseAuth.currentUser;

    // Check if user is authenticated and email matches
    if (currentUser == null) {
      debugPrint('❌ Password change failed: No user logged in');
      return false;
    }

    if (currentUser.email?.toLowerCase().trim() != normalizedEmail) {
      debugPrint(
          '❌ Password change failed: Email mismatch. Current: ${currentUser.email}, Requested: $normalizedEmail');
      return false;
    }

    try {
      // Re-authenticate user first (required for security)
      final credential = fb_auth.EmailAuthProvider.credential(
        email: normalizedEmail,
        password: oldPassword,
      );

      await currentUser.reauthenticateWithCredential(credential);
      debugPrint('✅ Re-authentication successful');

      // Update password
      await currentUser.updatePassword(newPassword);
      debugPrint('✅ Password updated in Firebase Auth');

      // Update password in local Firestore account
      final account = _accounts[normalizedEmail];
      if (account != null) {
        account.password = newPassword;
        final success = await _firestoreService.updateAuthAccount(
          account.email,
          account.toJson(),
        );
        if (success) {
          debugPrint('✅ Password updated in Firestore');
        } else {
          debugPrint('⚠️ Failed to update password in Firestore');
        }
      }

      return true;
    } on fb_auth.FirebaseAuthException catch (e) {
      debugPrint('❌ Firebase password change failed: ${e.code} - ${e.message}');

      // Return false with specific error code for UI to handle
      return false;
    } catch (e) {
      debugPrint('❌ Password change error: $e');
      return false;
    }
  }

  Future<bool> createAdminAccount({
    required String superAdminEmail,
    required String adminEmail,
    required String adminName,
    required String tenantId,
    required String password,
  }) async {
    final normalizedSuper = superAdminEmail.toLowerCase().trim();
    final normalizedAdmin = adminEmail.toLowerCase().trim();
    final normalizedTenantId = tenantId.toLowerCase().trim();

    final creator = _accounts[normalizedSuper];
    if (creator == null || creator.role != UserRole.superAdmin) {
      debugPrint('❌ createAdminAccount: Unauthorized - Not super admin');
      return false;
    }

    if (_accounts.containsKey(normalizedAdmin)) {
      debugPrint(
          '❌ createAdminAccount: Admin email already exists: $normalizedAdmin');
      return false;
    }

    // Create Firebase Auth user
    fb_auth.UserCredential? userCredential;
    try {
      userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedAdmin,
        password: password,
      );
      debugPrint('✅ Firebase Auth admin user created: $normalizedAdmin');
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') {
        debugPrint(
            '❌ Firebase Auth admin creation failed: ${e.code} ${e.message}');
        return false;
      }
      debugPrint('⚠️ Firebase Auth user already exists: $normalizedAdmin');
      try {
        userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: normalizedAdmin,
          password: password,
        );
      } catch (_) {}
    }

    // Set custom claims for the admin user via API
    if (userCredential != null && userCredential.user != null) {
      await _setCustomClaimsViaAPI(
        email: normalizedAdmin,
        role: 'admin',
        tenantId: normalizedTenantId,
      );
      await userCredential.user!.getIdToken(true);
    }

    final account = AuthAccount(
      email: normalizedAdmin,
      password: password,
      name: adminName,
      role: UserRole.admin,
      tenantId: normalizedTenantId,
      createdBy: creator.email,
    );

    _accounts[normalizedAdmin] = account;
    final success = await _firestoreService.addAuthAccount(
        normalizedAdmin, account.toJson());

    if (success) {
      debugPrint('✅ Admin account created successfully: $normalizedAdmin');
      notifyListeners();
      return true;
    } else {
      debugPrint(
          '❌ Firestore addAuthAccount failed for admin: $normalizedAdmin');
      _accounts.remove(normalizedAdmin);
      return false;
    }
  }

  // In auth_provider.dart, simplify the createStaffAccount method:

  Future<bool> createStaffAccount({
    required String adminEmail,
    required String staffEmail,
    required String staffName,
    required String tenantId,
  }) async {
    final normalizedAdmin = adminEmail.toLowerCase().trim();
    final normalizedStaff = staffEmail.toLowerCase().trim();
    final normalizedTenantId = tenantId.toLowerCase().trim();

    final creator = _accounts[normalizedAdmin];
    if (creator == null || creator.role != UserRole.admin) {
      debugPrint('❌ createStaffAccount: Unauthorized');
      return false;
    }

    if (_accounts.containsKey(normalizedStaff)) {
      debugPrint(
          '❌ createStaffAccount: Staff email already exists: $normalizedStaff');
      return false;
    }

    const defaultPassword = 'staff123';

    // Create Firebase Auth user
    fb_auth.UserCredential? userCredential;
    try {
      userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedStaff,
        password: defaultPassword,
      );
      debugPrint('✅ Firebase Auth user created for staff: $normalizedStaff');
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') {
        debugPrint(
            '❌ Firebase Auth staff creation failed: ${e.code} ${e.message}');
        return false;
      }
      debugPrint('⚠️ Firebase Auth user already exists: $normalizedStaff');
      try {
        userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: normalizedStaff,
          password: defaultPassword,
        );
      } catch (_) {}
    }

    // Set custom claims
    if (userCredential != null && userCredential.user != null) {
      await _setCustomClaimsViaAPI(
        email: normalizedStaff,
        role: 'staff',
        tenantId: normalizedTenantId,
      );
      await userCredential.user!.getIdToken(true);
      debugPrint('✅ Custom claims set for staff: $normalizedStaff');
    }

    final account = AuthAccount(
      email: normalizedStaff,
      password: defaultPassword,
      name: staffName,
      role: UserRole.staff,
      tenantId: normalizedTenantId,
      createdBy: creator.email,
    );

    _accounts[normalizedStaff] = account;

    // Single attempt to save to Firestore (no retry loop)
    final success = await _firestoreService.addAuthAccount(
        normalizedStaff, account.toJson());

    if (success) {
      debugPrint('✅ Staff account created successfully: $normalizedStaff');
      notifyListeners();
      return true;
    } else {
      debugPrint(
          '❌ Firestore addAuthAccount failed for staff: $normalizedStaff');
      return false;
    }
  }

  Future<StaffPasswordResult> setStaffPassword({
    required String adminEmail,
    required String staffEmail,
    required String password,
  }) async {
    final normalizedAdmin = adminEmail.toLowerCase().trim();
    final normalizedStaff = staffEmail.toLowerCase().trim();

    final creator = _accounts[normalizedAdmin];
    final staff = _accounts[normalizedStaff];

    if (creator == null || staff == null) {
      debugPrint('❌ setStaffPassword: Account not found');
      return StaffPasswordResult.failed;
    }

    if (creator.role != UserRole.admin) {
      debugPrint('❌ setStaffPassword: Unauthorized - Creator is not admin');
      return StaffPasswordResult.unauthorized;
    }

    if (staff.role != UserRole.staff) {
      debugPrint('❌ setStaffPassword: Target is not staff');
      return StaffPasswordResult.unauthorized;
    }

    if (staff.tenantId != creator.tenantId) {
      debugPrint('❌ setStaffPassword: Tenant mismatch');
      return StaffPasswordResult.unauthorized;
    }

    try {
      // Call the change password API
      final response = await http
          .post(
            Uri.parse(ApiConfig.changePasswordEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'adminEmail': adminEmail,
              'staffEmail': staffEmail,
              'newPassword': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Update local password storage
        staff.password = password;
        await _firestoreService.updateAuthAccount(staff.email, staff.toJson());
        _accounts[normalizedStaff] = staff;

        notifyListeners();
        debugPrint('✅ Staff password updated successfully: ${staff.email}');
        return StaffPasswordResult.updated;
      } else {
        debugPrint('❌ API error: ${data['error']}');
        return StaffPasswordResult.failed;
      }
    } catch (e) {
      debugPrint('❌ Error calling password change API: $e');
      return StaffPasswordResult.failed;
    }
  }

  Future<bool> deleteStaffAccount({
    required String adminEmail,
    required String staffEmail,
  }) async {
    final normalizedAdmin = adminEmail.toLowerCase().trim();
    final normalizedStaff = staffEmail.toLowerCase().trim();

    final creator = _accounts[normalizedAdmin];
    final staff = _accounts[normalizedStaff];

    if (creator == null || staff == null) {
      return false;
    }

    if (creator.role != UserRole.admin || staff.role != UserRole.staff) {
      return false;
    }

    if (staff.tenantId != creator.tenantId) {
      return false;
    }

    _accounts.remove(normalizedStaff);
    final success = await _firestoreService.deleteAuthAccount(staff.email);

    if (success) {
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> changeStaffPasswordViaAPI({
    required String adminEmail,
    required String staffEmail,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.changePasswordEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'adminEmail': adminEmail,
              'staffEmail': staffEmail,
              'newPassword': newPassword,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final staff = _accounts[staffEmail.toLowerCase().trim()];
        if (staff != null) {
          staff.password = newPassword;
          await _firestoreService.updateAuthAccount(
              staff.email, staff.toJson());
          notifyListeners();
        }
        debugPrint('✅ Password changed via API: $staffEmail');
        return true;
      } else {
        debugPrint('❌ API error: ${data['error']}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to call API: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _currentTenantId = null;
    await _firebaseAuth.signOut();
    await _prefs.remove('user');
    await _prefs.remove('currentTenant');
    notifyListeners();
  }
}

enum StaffPasswordResult {
  updated,
  resetEmailSent,
  unauthorized,
  failed,
}

class AuthAccount {
  final String email;
  String? password;
  final String name;
  final UserRole role;
  final String? tenantId;
  final String createdBy;

  AuthAccount({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    this.tenantId,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'email': email,
      'name': name,
      'role': role.name,
      'tenantId': tenantId,
      'createdBy': createdBy,
    };
    if (password != null) {
      json['password'] = password;
    }
    return json;
  }

  factory AuthAccount.fromJson(Map<String, dynamic> json) {
    final email = ((json['email'] as String?) ?? (json['id'] as String?) ?? '')
        .toLowerCase()
        .trim();
    return AuthAccount(
      email: email,
      password: json['password'] as String?,
      name: json['name'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == (json['role'] as String? ?? ''),
        orElse: () => UserRole.staff,
      ),
      tenantId: (json['tenantId'] as String?)?.toLowerCase().trim(),
      createdBy: json['createdBy'] as String? ?? 'system',
    );
  }
}
