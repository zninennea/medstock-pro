import 'package:flutter/material.dart';

class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? tenantId;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.tenantId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.name,
        'tenantId': tenantId,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        role: UserRole.values.firstWhere((e) => e.name == json['role']),
        tenantId: (json['tenantId'] as String?)?.toLowerCase().trim(),
      );
}

enum UserRole {
  superAdmin,
  admin,
  staff,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.staff:
        return 'Staff';
    }
  }

  Color get color {
    switch (this) {
      case UserRole.superAdmin:
        return Colors.purple;
      case UserRole.admin:
        return Colors.blue;
      case UserRole.staff:
        return Colors.green;
    }
  }
}
