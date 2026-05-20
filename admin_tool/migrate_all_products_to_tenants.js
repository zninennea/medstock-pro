// admin_tool/migrate_all_products_to_tenants.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateAllProducts() {
    console.log('\n=== Migrating All Products to Tenant Subcollections ===\n');

    // Get all products from old top-level collection
    const oldProductsSnapshot = await db.collection('products').get();

    console.log(`Found ${oldProductsSnapshot.size} products in top-level collection\n`);

    let migrated = 0;
    let failed = 0;
    let skipped = 0;

    for (const doc of oldProductsSnapshot.docs) {
        const data = doc.data();
        let tenantId = data.tenantId;

        // If no tenantId, try to determine from product data or use default
        if (!tenantId) {
            // Check if product belongs to davmedical or cebgeneral based on name or other fields
            const productName = (data.meds || '').toLowerCase();
            if (productName.includes('davao') || data.supplier === 'Medcor Pharma') {
                tenantId = 'davmedical';
            } else if (productName.includes('cebu')) {
                tenantId = 'cebgeneral';
            } else {
                // Default to davmedical for unknown
                tenantId = 'davmedical';
            }
            console.log(`⚠️ Product ${doc.id} had no tenantId, assigning to: ${tenantId}`);
        }

        // Check if tenant exists
        const tenantDoc = await db.collection('tenants').doc(tenantId).get();
        if (!tenantDoc.exists) {
            console.log(`❌ Tenant ${tenantId} does not exist, skipping product ${doc.id}`);
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
                console.log(`⏭️ Product already exists in tenant ${tenantId}: ${doc.id}`);
                skipped++;
                continue;
            }

            // Prepare product data without the old tenantId field (since it's now in subcollection path)
            const { tenantId: _, ...productData } = data;

            // Add to tenant subcollection
            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('products')
                .doc(doc.id)
                .set({
                    ...productData,
                    migratedAt: admin.firestore.FieldValue.serverTimestamp(),
                    originalTenantId: data.tenantId || tenantId
                });

            console.log(`✅ Migrated ${doc.id} to tenant ${tenantId}`);
            migrated++;

        } catch (error) {
            console.log(`❌ Failed to migrate ${doc.id}: ${error.message}`);
            failed++;
        }
    }

    console.log(`\n=== Migration Summary ===`);
    console.log(`✅ Migrated: ${migrated}`);
    console.log(`⏭️ Skipped: ${skipped}`);
    console.log(`❌ Failed: ${failed}`);

    // Show final counts per tenant
    console.log('\n=== Final Product Counts Per Tenant ===\n');
    const tenants = ['davmedical', 'cebgeneral', 'med_cares'];

    for (const tenantId of tenants) {
        const productsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .get();

        console.log(`📁 ${tenantId}: ${productsSnapshot.size} products`);

        // List first few products
        let count = 0;
        for (const doc of productsSnapshot.docs) {
            const data = doc.data();
            console.log(`   - ${data.meds || doc.id} (Qty: ${data.qty || 0})`);
            count++;
            if (count >= 5) {
                if (productsSnapshot.size > 5) {
                    console.log(`   ... and ${productsSnapshot.size - 5} more`);
                }
                break;
            }
        }
    }

    console.log('\n✅ Migration complete!\n');
    console.log('⚠️ The old top-level products collection still has data.');
    console.log('After verifying products appear correctly in the app, you can delete the old collection.');
}

migrateAllProducts();