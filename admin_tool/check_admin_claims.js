// admin_tool/check_admin_claims.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function checkAdminClaims() {
    console.log('\n=== Checking Admin Custom Claims ===\n');

    const admins = [
        'erick0318garcia@gmail.com',
        'admin@davmedical.com',
        'admin@cebgeneral.com'
    ];

    for (const email of admins) {
        try {
            const user = await admin.auth().getUserByEmail(email);
            const claims = user.customClaims || {};

            console.log(`📧 ${email}`);
            console.log(`   Role: ${claims.role || 'NOT SET'}`);
            console.log(`   TenantId: ${claims.tenantId || 'NOT SET'}`);

            let tenantId = claims.tenantId;
            if (email === 'erick0318garcia@gmail.com' && claims.tenantId !== 'med_cares') {
                tenantId = 'med_cares';
                console.log(`   ⚠️ Fixing tenantId to 'med_cares'...`);
                await admin.auth().setCustomUserClaims(user.uid, {
                    role: 'admin',
                    tenantId: 'med_cares'
                });
                console.log(`   ✅ Fixed!`);
            }
            console.log('');

        } catch (error) {
            console.log(`❌ Error for ${email}: ${error.message}\n`);
        }
    }
}

checkAdminClaims();