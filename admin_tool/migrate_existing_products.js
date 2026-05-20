// admin_tool/migrate_existing_products.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateExistingProducts() {
    console.log('\n=== Migrating Existing Products to Tenant Subcollections ===\n');

    // Get all products from the old top-level collection
    const oldProductsSnapshot = await db.collection('products').get();

    console.log(`Found ${oldProductsSnapshot.size} products in top-level collection\n`);

    let migrated = 0;
    let skipped = 0;
    let failed = 0;

    for (const doc of oldProductsSnapshot.docs) {
        const data = doc.data();
        const tenantId = data.tenantId;

        if (!tenantId) {
            console.log(`⚠️ Skipping ${doc.id} - no tenantId field`);
            skipped++;
            continue;
        }

        try {
            // Check if product already exists in tenant subcollection
            const existingProduct = await db
                .collection('tenants')
                .doc(tenantId)
                .collection('products')
                .doc(doc.id)
                .get();

            if (existingProduct.exists) {
                console.log(`⏭️ Product already exists in tenant subcollection: ${doc.id}`);
                skipped++;
                continue;
            }

            // Copy to tenant subcollection
            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('products')
                .doc(doc.id)
                .set({
                    ...data,
                    migratedAt: admin.firestore.FieldValue.serverTimestamp()
                });

            console.log(`✅ Migrated ${doc.id} to tenant ${tenantId}`);
            migrated++;

            // Optional: Delete the old document to avoid confusion
            // Uncomment the line below if you want to delete old products
            // await db.collection('products').doc(doc.id).delete();

        } catch (error) {
            console.log(`❌ Failed to migrate ${doc.id}: ${error.message}`);
            failed++;
        }
    }

    console.log(`\n=== Migration Summary ===`);
    console.log(`✅ Migrated: ${migrated}`);
    console.log(`⏭️ Skipped: ${skipped}`);
    console.log(`❌ Failed: ${failed}`);

    // Also check for any tenants that might need demo products seeded
    console.log('\n=== Checking Tenants ===\n');
    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const productsSubcollection = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .limit(1)
            .get();

        if (productsSubcollection.empty) {
            console.log(`⚠️ Tenant ${tenantId} has no products. You may need to add products manually.`);
        } else {
            console.log(`✅ Tenant ${tenantId} has products`);
        }
    }

    console.log('\n✅ Migration complete!\n');
}

migrateExistingProducts();