// admin_tool/fix_tenant_paid_status.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixTenantPaidStatus() {
    console.log('\n=== Fixing Tenant Paid Status ===\n');

    const tenantsSnapshot = await db.collection('tenants').get();

    for (const doc of tenantsSnapshot.docs) {
        const data = doc.data();
        const tenantId = doc.id;
        const isPaid = data.paid === true;

        console.log(`📁 ${tenantId}: paid = ${isPaid}`);

        // If you know which tenants should be paid, update them here
        // For example, set med_cares to paid:
        if (tenantId === 'med_cares') {
            await db.collection('tenants').doc(tenantId).update({
                'paid': false, // Change to true if they should be paid
                'lastPaymentDate': null
            });
            console.log(`   ✅ Reset ${tenantId} paid status`);
        }
    }

    console.log('\n✅ Done!');
}

fixTenantPaidStatus();