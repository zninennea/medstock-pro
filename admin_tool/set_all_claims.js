const admin = require('firebase-admin');
const readline = require('readline-sync');

// Initialize Firebase Admin
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function setClaims() {
    console.log('\n=== Set Admin Claims ===\n');

    const email = readline.question('Enter user email: ');
    const role = readline.question('Enter role (superAdmin/admin/staff): ');
    const tenantId = readline.question('Enter tenantId (or leave empty for superAdmin): ');

    if (!email || !role) {
        console.log('❌ Email and role are required');
        return;
    }

    const validRoles = ['superAdmin', 'admin', 'staff'];
    if (!validRoles.includes(role)) {
        console.log(`❌ Invalid role. Must be one of: ${validRoles.join(', ')}`);
        return;
    }

    try {
        const user = await admin.auth().getUserByEmail(email);

        const claims = {
            role: role,
            tenantId: tenantId || null
        };

        await admin.auth().setCustomUserClaims(user.uid, claims);

        console.log(`\n✅ Claims set for ${email}:`);
        console.log(`   Role: ${role}`);
        console.log(`   TenantId: ${tenantId || 'null'}`);

        console.log('\nYou can now use this account with the admin API.');

    } catch (error) {
        if (error.code === 'auth/user-not-found') {
            console.log(`\n❌ User not found: ${email}`);
            console.log('Create the user first in Firebase Console -> Authentication');
        } else {
            console.log(`\n❌ Error: ${error.message}`);
        }
    }
}

setClaims();