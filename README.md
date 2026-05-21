# MedStock Pro - Advanced Pharmacy Inventory System

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)](https://firebase.google.com)

## 🏥 Overview

MedStock Pro is a comprehensive multi-tenant pharmacy inventory management system built with Flutter and Firebase. It provides real-time inventory tracking, stock management, transaction recording, and payment processing for multiple pharmacy tenants.

## ✨ Features

### 🏢 Multi-Tenant Architecture
- Isolated data per tenant
- Super admin dashboard for tenant management
- Tenant-specific staff accounts

### 📦 Product Management
- CRUD operations for products
- Stock level tracking
- Expiry date monitoring
- Low stock alerts
- Batch/Lot number tracking

### 📊 Transactions
- Stock IN/OUT recording
- Transaction history with pagination
- Audit trail for all activities
- Multiple reason categories

### 👥 Staff Management
- Role-based access (Super Admin, Admin, Staff)
- Staff account creation
- Secure password management

### 💳 Payment Processing
- Cash and GCash payments
- Receipt upload and storage
- Payment verification
- Monthly billing tracking
- Payment due alerts

### 📈 Analytics
- Real-time dashboard metrics
- Inventory value calculation
- Stock turnover rate
- Top movers tracking
- Expiry calendar

### 🎨 UI/UX
- Responsive design (Mobile + Desktop)
- Dark/Light theme support
- Interactive charts
- Paginated tables
- Offline support

## 🛠️ Tech Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Firebase
  - Firebase Authentication
  - Cloud Firestore
  - Firebase Storage
- **State Management:** Provider
- **Charts:** fl_chart
- **Excel Export:** Excel package

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Firebase account
- Node.js (for admin tools)

### Installation

1. Clone the repository
```bash
git clone https://github.com/YOUR_USERNAME/medstock-pro.git
cd medstock-pro