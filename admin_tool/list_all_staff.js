// admin_tool/list_all_staff.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function listAllStaff() {
    console.log('\n=== All Staff Accounts ===\n');

    // Get all users from Firebase Auth
    const listUsersResult = await admin.auth().listUsers(1000);

    console.log('Users with staff role:\n');

    for (const user of listUsersResult.users) {
        const email = user.email;
        if (!email) continue;

        const claims = user.customClaims || {};

        if (claims.role === 'staff') {
            console.log(`📧 ${email}`);
            console.log(`   Tenant: ${claims.tenantId || 'NOT SET'}`);
            console.log(`   UID: ${user.uid}`);
            const creationTime = user.metadata.creationTime;
            console.log(`   Created: ${creationTime || 'Unknown'}`);
            console.log('');
        }
    }

    // Also check Firestore for staff records
    console.log('\n=== Staff Records in Firestore ===\n');

    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const staffSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('staff')
            .get();

        if (!staffSnapshot.empty) {
            console.log(`📁 Tenant: ${tenantId}`);
            for (const doc of staffSnapshot.docs) {
                const data = doc.data();
                const staffName = data.name || 'Unknown';
                const staffRole = data.role || 'Unknown';
                console.log(`   - ${doc.id}: ${staffName} (Role: ${staffRole})`);
            }
            console.log('');
        }
    }
}

listAllStaff();