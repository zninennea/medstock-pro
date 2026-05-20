// admin_tool/check_staff_claims.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function checkStaffClaims() {
    console.log('\n=== Checking Staff Custom Claims ===\n');

    const staffEmails = [
        'maria.santos@davmedical.com',
        'jun.reyes@davmedical.com'
    ];

    for (const email of staffEmails) {
        try {
            const user = await admin.auth().getUserByEmail(email);
            const claims = user.customClaims || {};

            console.log(`📧 ${email}`);
            console.log(`   Role: ${claims.role || 'NOT SET'}`);
            console.log(`   TenantId: ${claims.tenantId || 'NOT SET'}`);

            if (claims.role !== 'staff') {
                console.log(`   ⚠️ Fixing role to 'staff'...`);
                await admin.auth().setCustomUserClaims(user.uid, {
                    role: 'staff',
                    tenantId: 'davmedical'
                });
                console.log(`   ✅ Fixed!`);
            }
            console.log('');

        } catch (error) {
            console.log(`❌ Error for ${email}: ${error.message}\n`);
        }
    }
}

checkStaffClaims();