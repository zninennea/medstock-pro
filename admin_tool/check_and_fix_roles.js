const admin = require('firebase-admin');
const readline = require('readline-sync');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function checkAndFixRoles() {
    console.log('\n=== Check and Fix User Roles ===\n');

    // List all users you want to check
    const emails = [
        'erick0318garcia@gmail.com',
        'maria.santos@davmedical.com',
        'jun.reyes@davmedical.com',
        'admin@davmedical.com',
        'admin@cebgeneral.com',
        'superadmin@medstock.pro'
    ];

    console.log('Checking user roles:\n');

    for (const email of emails) {
        try {
            const user = await admin.auth().getUserByEmail(email);
            const claims = user.customClaims || {};

            console.log(`📧 ${email}`);
            console.log(`   UID: ${user.uid}`);
            console.log(`   Current role: ${claims.role || 'NOT SET'}`);
            console.log(`   Current tenantId: ${claims.tenantId || 'NOT SET'}`);

            // Determine what role this user should have
            let expectedRole = 'staff';
            let expectedTenantId = null;

            if (email === 'superadmin@medstock.pro') {
                expectedRole = 'superAdmin';
                expectedTenantId = null;
            } else if (email === 'admin@davmedical.com') {
                expectedRole = 'admin';
                expectedTenantId = 'davmedical';
            } else if (email === 'admin@cebgeneral.com') {
                expectedRole = 'admin';
                expectedTenantId = 'cebgeneral';
            } else if (email === 'erick0318garcia@gmail.com') {
                expectedRole = 'admin';
                expectedTenantId = 'davmedical';
            } else if (email.includes('maria') || email.includes('jun')) {
                expectedRole = 'staff';
                expectedTenantId = 'davmedical';
            }

            console.log(`   Expected role: ${expectedRole}`);
            console.log(`   Expected tenantId: ${expectedTenantId || 'null'}`);

            // Fix if needed
            if (claims.role !== expectedRole || claims.tenantId !== expectedTenantId) {
                console.log(`   🔧 Fixing...`);
                await admin.auth().setCustomUserClaims(user.uid, {
                    role: expectedRole,
                    tenantId: expectedTenantId
                });
                console.log(`   ✅ Fixed! New role: ${expectedRole}`);
            } else {
                console.log(`   ✅ Already correct`);
            }
            console.log('');

        } catch (error) {
            console.log(`❌ Error for ${email}: ${error.message}\n`);
        }
    }

    console.log('✅ Check complete!\n');
}

checkAndFixRoles();