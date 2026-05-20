const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function setClaimsForAllUsers() {
    console.log('\n=== Setting Claims for All Users ===\n');

    // Fetch all users from Firebase Auth
    const listUsersResult = await admin.auth().listUsers(1000);

    console.log(`Found ${listUsersResult.users.length} users\n`);

    for (const user of listUsersResult.users) {
        const email = user.email;
        if (!email) continue;

        console.log(`Processing: ${email}`);

        // Determine role and tenantId based on email or existing data
        let role = 'staff';
        let tenantId = null;

        // Check if user already has claims
        const existingClaims = user.customClaims || {};

        // Determine role from email patterns or existing claims
        if (email === 'superadmin@medstock.pro') {
            role = 'superAdmin';
            tenantId = null;
        } else if (email.includes('admin@')) {
            role = 'admin';
            // Extract tenant from email or use existing
            if (email.includes('davmedical')) {
                tenantId = 'davmedical';
            } else if (email.includes('cebgeneral')) {
                tenantId = 'cebgeneral';
            } else if (existingClaims.tenantId) {
                tenantId = existingClaims.tenantId;
            } else {
                // For other admin emails, ask or use default
                tenantId = 'davmedical';
            }
        } else if (email.includes('maria') || email.includes('jun')) {
            role = 'staff';
            tenantId = 'davmedical';
        } else if (existingClaims.role) {
            // Keep existing claims
            role = existingClaims.role;
            tenantId = existingClaims.tenantId;
        } else {
            // Default for unknown users
            role = 'staff';
            tenantId = 'davmedical';
        }

        // Set or update claims
        try {
            await admin.auth().setCustomUserClaims(user.uid, {
                role: role,
                tenantId: tenantId
            });
            console.log(`  ✅ Set: role=${role}, tenantId=${tenantId || 'null'}`);
        } catch (error) {
            console.log(`  ❌ Error: ${error.message}`);
        }

        console.log('');
    }

    console.log('✅ All users processed!\n');
}

setClaimsForAllUsers();