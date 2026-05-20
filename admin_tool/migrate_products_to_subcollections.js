// admin_tool/migrate_products_to_subcollections.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateProducts() {
    console.log('\n=== Migrating Products to Tenant Subcollections ===\n');

    // Get all products from old collection
    const productsSnapshot = await db.collection('products').get();

    console.log(`Found ${productsSnapshot.size} products to migrate\n`);

    let migrated = 0;
    let failed = 0;

    for (const doc of productsSnapshot.docs) {
        const data = doc.data();
        const tenantId = data.tenantId;

        if (!tenantId) {
            console.log(`❌ Skipping ${doc.id} - no tenantId`);
            failed++;
            continue;
        }

        try {
            // Copy to tenant subcollection
            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('products')
                .doc(doc.id)
                .set(data);

            console.log(`✅ Migrated ${doc.id} to tenant ${tenantId}`);
            migrated++;

            // Optional: Delete old document
            // await db.collection('products').doc(doc.id).delete();

        } catch (error) {
            console.log(`❌ Failed to migrate ${doc.id}: ${error.message}`);
            failed++;
        }
    }

    console.log(`\n=== Migration Complete ===`);
    console.log(`✅ Migrated: ${migrated}`);
    console.log(`❌ Failed: ${failed}`);
}

migrateProducts();