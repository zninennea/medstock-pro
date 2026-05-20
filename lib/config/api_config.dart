// lib/config/api_config.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // REPLACE THIS WITH YOUR ACTUAL IP ADDRESS
  // Run 'ipconfig' in terminal to find your IPv4 address
  static const String yourIpAddress = '192.168.56.1:3000'; // CHANGE THIS to your IP
  
  static String get baseUrl {
    // For web platform
    if (kIsWeb) {
      // Use your actual IP address instead of localhost
      return 'http://192.168.56.1:3000';
    }
    
    // For Android emulator
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    
    // For iOS simulator
    if (Platform.isIOS) {
      return 'http://localhost:3000';
    } 
    
    // Default
    return 'http://localhost:3000';
  }
  
  static String get setClaimsEndpoint => '$baseUrl/api/set-custom-claims';
  static String get changePasswordEndpoint => '$baseUrl/api/change-password';
  static String get statusEndpoint => '$baseUrl/api/status';
}