// admin_tool/check_audit_entries.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkAuditEntries() {
    console.log('\n=== CHECKING AUDIT ENTRIES ===\n');

    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const tenantData = tenantDoc.data();
        const tenantName = tenantData.name || tenantId;

        console.log(`\n📁 Tenant: ${tenantName} (${tenantId})`);

        const auditSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('audit')
            .orderBy('timestamp', 'desc')
            .limit(10)
            .get();

        console.log(`   Found ${auditSnapshot.size} audit entries`);

        for (const doc of auditSnapshot.docs) {
            const data = doc.data();
            console.log(`   - ${data.action}: ${data.details?.substring(0, 50)}... (by ${data.user})`);
        }

        if (auditSnapshot.size === 0) {
            console.log('   ⚠️ No audit entries found!');
        }
    }

    console.log('\n✅ Check complete!\n');
}

checkAuditEntries();