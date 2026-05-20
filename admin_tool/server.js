const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

// Initialize Firebase Admin
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// Create express app - ONLY ONCE
const app = express();

// Middleware
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(bodyParser.json());

// ============================================
// ENDPOINT 1: Set Custom Claims
// ============================================
app.post('/api/set-custom-claims', async(req, res) => {
    const { email, role, tenantId } = req.body;

    console.log(`\n📝 Setting custom claims for: ${email}`);
    console.log(`   Role: ${role}`);
    console.log(`   TenantId: ${tenantId || 'null'}`);

    if (!email || !role) {
        return res.status(400).json({
            success: false,
            error: 'Email and role are required'
        });
    }

    const validRoles = ['superAdmin', 'admin', 'staff'];
    if (!validRoles.includes(role)) {
        return res.status(400).json({
            success: false,
            error: `Invalid role. Must be one of: ${validRoles.join(', ')}`
        });
    }

    try {
        // Check if user exists
        let user;
        try {
            user = await admin.auth().getUserByEmail(email);
            console.log(`   ✅ User found: ${user.uid}`);
        } catch (error) {
            if (error.code === 'auth/user-not-found') {
                console.log(`   ❌ User not found: ${email}`);
                return res.status(404).json({
                    success: false,
                    error: `User not found: ${email}`
                });
            }
            throw error;
        }

        // Set custom claims
        const claims = {
            role: role,
            tenantId: tenantId || null
        };

        await admin.auth().setCustomUserClaims(user.uid, claims);
        console.log(`   ✅ Custom claims set successfully`);

        res.json({
            success: true,
            message: `Custom claims set for ${email}`,
            claims: claims
        });

    } catch (error) {
        console.error('   ❌ Error:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ============================================
// ENDPOINT 2: Change Staff Password
// ============================================
app.post('/api/change-password', async(req, res) => {
    const { staffEmail, newPassword, adminEmail } = req.body;

    console.log(`\n🔐 Password change request:`);
    console.log(`   Staff: ${staffEmail}`);
    console.log(`   Admin: ${adminEmail}`);
    console.log(`   New Password: ${newPassword}`);

    if (!staffEmail || !newPassword) {
        return res.status(400).json({
            success: false,
            error: 'Email and password are required'
        });
    }

    if (newPassword.length < 6) {
        return res.status(400).json({
            success: false,
            error: 'Password must be at least 6 characters'
        });
    }

    try {
        // Verify the admin exists and has proper role
        let adminUser;
        try {
            adminUser = await admin.auth().getUserByEmail(adminEmail);
            console.log(`   Admin UID: ${adminUser.uid}`);
        } catch (error) {
            console.log(`   ❌ Admin not found: ${error.message}`);
            return res.status(401).json({
                success: false,
                error: 'Admin user not found'
            });
        }

        const adminClaims = adminUser.customClaims || {};
        console.log(`   Admin role: ${adminClaims.role}`);

        if (adminClaims.role !== 'admin' && adminClaims.role !== 'superAdmin') {
            return res.status(403).json({
                success: false,
                error: `Unauthorized: Your role is '${adminClaims.role || 'none'}'. Only admins can change passwords.`
            });
        }

        // Get the staff user
        let staffUser;
        try {
            staffUser = await admin.auth().getUserByEmail(staffEmail);
            console.log(`   Staff UID: ${staffUser.uid}`);
            console.log(`   Staff current custom claims:`, staffUser.customClaims || {});
        } catch (error) {
            console.log(`   ❌ Staff not found: ${error.message}`);
            return res.status(404).json({
                success: false,
                error: `Staff user not found: ${staffEmail}`
            });
        }

        // Don't strictly check for staff role - allow any non-admin user
        const staffClaims = staffUser.customClaims || {};
        if (staffClaims.role === 'admin' || staffClaims.role === 'superAdmin') {
            console.log(`   ❌ Cannot change password for admin/superAdmin accounts`);
            return res.status(403).json({
                success: false,
                error: 'Cannot change password for admin accounts'
            });
        }

        // Update password
        await admin.auth().updateUser(staffUser.uid, {
            password: newPassword
        });

        console.log(`   ✅ Password changed successfully for: ${staffEmail}`);
        console.log(`   New password set to: ${newPassword}`);

        res.json({
            success: true,
            message: `Password changed successfully for ${staffEmail}`,
            password: newPassword
        });

    } catch (error) {
        console.error('   ❌ Error:', error);
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// ============================================
// ENDPOINT 3: Server Status
// ============================================
app.get('/api/status', (req, res) => {
    res.json({
        status: 'running',
        message: 'Admin API server is running'
    });
});

// ============================================
// START SERVER
// ============================================
const PORT = 3000;
const HOST = '0.0.0.0';

app.listen(PORT, HOST, () => {
    console.log(`\n✅ Admin API Server running on http://${HOST}:${PORT}`);
    console.log(`   Accessible at:`);
    console.log(`   - http://localhost:${PORT}`);
    console.log(`   - http://YOUR_IP_ADDRESS:${PORT}`);
    console.log(`\n📋 Available endpoints:`);
    console.log(`   POST http://localhost:${PORT}/api/set-custom-claims`);
    console.log(`   POST http://localhost:${PORT}/api/change-password`);
    console.log(`   GET  http://localhost:${PORT}/api/status`);
    console.log('\n💡 Keep this terminal window open while using the app!\n');
});