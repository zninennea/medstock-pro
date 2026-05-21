// admin_tool/reset_seeded_flag.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function resetSeededFlag() {
    console.log('\n=== RESETTING SEEDED FLAGS ===\n');

    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const metadataRef = db
            .collection('tenants')
            .doc(tenantId)
            .collection('_metadata')
            .doc('seeded');

        const metadataDoc = await metadataRef.get();
        if (metadataDoc.exists) {
            await metadataRef.delete();
            console.log(`✅ Reset seeded flag for tenant: ${tenantId}`);
        } else {
            console.log(`ℹ️ No seeded flag for tenant: ${tenantId}`);
        }
    }

    console.log('\n✅ Reset complete! Next time you load products, fresh demos will be seeded.\n');
}

resetSeededFlag();