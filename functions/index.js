// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

// Cloud Function to allow admins to set staff passwords
exports.adminSetStaffPassword = functions.https.onCall(async(data, context) => {
    console.log('=== adminSetStaffPassword called ===');
    console.log('Request data:', data);
    console.log('Auth context:', context.auth);

    // Check if user is authenticated
    if (!context.auth) {
        console.error('ERROR: User not authenticated');
        throw new functions.https.HttpsError(
            'unauthenticated',
            'You must be logged in to perform this action'
        );
    }

    const uid = context.auth.uid;
    console.log('User UID:', uid);

    // Get the user's custom claims
    let userClaims;
    try {
        const user = await admin.auth().getUser(uid);
        userClaims = user.customClaims || {};
        console.log('User claims:', userClaims);
    } catch (error) {
        console.error('Error getting user claims:', error);
        throw new functions.https.HttpsError(
            'internal',
            'Error verifying user permissions'
        );
    }

    const userRole = userClaims.role;
    const userTenantId = userClaims.tenantId;

    console.log('User role:', userRole);
    console.log('User tenantId:', userTenantId);

    // Check if user has admin or superAdmin role
    if (userRole !== 'admin' && userRole !== 'superAdmin') {
        console.error('ERROR: Permission denied - user role is:', userRole);
        throw new functions.https.HttpsError(
            'permission-denied',
            'Only admins can change staff passwords'
        );
    }

    const { staffEmail, newPassword, tenantId } = data;

    console.log('Target staffEmail:', staffEmail);
    console.log('Provided tenantId:', tenantId);
    console.log('User tenantId:', userTenantId);

    // Validate input
    if (!staffEmail || !newPassword || !tenantId) {
        console.error('ERROR: Missing required fields');
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Missing required fields: staffEmail, newPassword, tenantId'
        );
    }

    // Check password strength
    if (newPassword.length < 6) {
        console.error('ERROR: Password too short');
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Password must be at least 6 characters long'
        );
    }

    // Verify tenant match (unless superAdmin)
    if (userRole !== 'superAdmin' && userTenantId !== tenantId) {
        console.error('ERROR: Tenant mismatch - user tenant:', userTenantId, 'request tenant:', tenantId);
        throw new functions.https.HttpsError(
            'permission-denied',
            'You can only manage staff from your own tenant'
        );
    }

    try {
        // Get the staff user by email
        let userRecord;
        try {
            userRecord = await admin.auth().getUserByEmail(staffEmail);
            console.log('Found user:', userRecord.uid);
        } catch (error) {
            if (error.code === 'auth/user-not-found') {
                console.error('ERROR: Staff user not found:', staffEmail);
                throw new functions.https.HttpsError(
                    'not-found',
                    `Staff user with email ${staffEmail} not found`
                );
            }
            throw error;
        }

        // Check if the user is a staff member
        const staffClaims = userRecord.customClaims || {};
        if (staffClaims.role !== 'staff') {
            console.error('ERROR: User is not a staff member. Role:', staffClaims.role);
            throw new functions.https.HttpsError(
                'permission-denied',
                'Target user is not a staff account'
            );
        }

        // Update the user's password
        await admin.auth().updateUser(userRecord.uid, {
            password: newPassword
        });

        console.log('✅ Password updated successfully for:', staffEmail);

        // Return success
        return {
            success: true,
            message: 'Password updated successfully'
        };

    } catch (error) {
        console.error('❌ Error updating password:', error);
        throw new functions.https.HttpsError(
            'internal',
            error.message || 'Failed to update password'
        );
    }
});

// Optional: Cloud Function to create staff users
exports.createStaffUser = functions.https.onCall(async(data, context) => {
    console.log('=== createStaffUser called ===');

    // Check authentication
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const uid = context.auth.uid;
    const user = await admin.auth().getUser(uid);
    const userClaims = user.customClaims || {};
    const userRole = userClaims.role;
    const userTenantId = userClaims.tenantId;

    if (userRole !== 'admin' && userRole !== 'superAdmin') {
        throw new functions.https.HttpsError('permission-denied', 'Only admins can create staff');
    }

    const { staffEmail, staffName, tenantId } = data;

    if (userRole !== 'superAdmin' && userTenantId !== tenantId) {
        throw new functions.https.HttpsError('permission-denied', 'Tenant mismatch');
    }

    try {
        // Create the staff user
        const tempPassword = Math.random().toString(36).slice(-8);
        const userRecord = await admin.auth().createUser({
            email: staffEmail,
            password: tempPassword,
            displayName: staffName,
            emailVerified: true,
        });

        // Set custom claims for staff role
        await admin.auth().setCustomUserClaims(userRecord.uid, {
            role: 'staff',
            tenantId: tenantId,
        });

        console.log('✅ Staff user created:', staffEmail);

        // Send password reset email
        await admin.auth().generatePasswordResetLink(staffEmail);

        return {
            success: true,
            message: 'Staff user created successfully',
            temporaryPassword: tempPassword
        };

    } catch (error) {
        console.error('Error creating staff:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});