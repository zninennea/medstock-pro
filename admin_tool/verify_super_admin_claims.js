// admin_tool/verify_super_admin_claims.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function verifySuperAdmin() {
    console.log('\n=== Verifying Super Admin Claims ===\n');

    const email = 'superadmin@medstock.pro';

    try {
        const user = await admin.auth().getUserByEmail(email);
        const claims = user.customClaims || {};

        console.log(`📧 ${email}`);
        console.log(`   Role: ${claims.role || 'NOT SET'}`);
        console.log(`   TenantId: ${claims.tenantId || 'null'}`);

        if (claims.role !== 'superAdmin') {
            console.log(`   🔧 Fixing...`);
            await admin.auth().setCustomUserClaims(user.uid, {
                role: 'superAdmin',
                tenantId: null
            });
            console.log(`   ✅ Fixed!`);
        } else {
            console.log(`   ✅ Already correct`);
        }
    } catch (error) {
        console.log(`❌ Error: ${error.message}`);
    }
}

verifySuperAdmin();