// admin_tool/check_super_admin.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function checkSuperAdmin() {
    console.log('\n=== CHECKING SUPER ADMIN CLAIMS ===\n');

    const email = 'superadmin@medstock.pro';

    try {
        const user = await admin.auth().getUserByEmail(email);
        const claims = user.customClaims || {};

        console.log(`📧 ${email}`);
        console.log(`   Current role: ${claims.role || 'NOT SET'}`);
        console.log(`   Current tenantId: ${claims.tenantId || 'null'}`);

        if (claims.role !== 'superAdmin') {
            console.log(`\n🔧 Fixing claims...`);
            await admin.auth().setCustomUserClaims(user.uid, {
                role: 'superAdmin',
                tenantId: null
            });
            console.log(`✅ Fixed! Super Admin claims updated.`);
        } else {
            console.log(`\n✅ Super Admin claims are correct!`);
        }

        // Verify the claims were set
        const updatedUser = await admin.auth().getUserByEmail(email);
        console.log(`\n📋 Verified claims: ${JSON.stringify(updatedUser.customClaims)}`);

    } catch (error) {
        console.log(`❌ Error: ${error.message}`);
    }
}

checkSuperAdmin();