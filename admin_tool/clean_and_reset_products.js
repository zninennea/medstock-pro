// admin_tool/clean_and_reset_products.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function cleanAndResetProducts() {
    console.log('\n=== Cleaning and Resetting Products ===\n');

    // 1. Delete all products from top-level collection
    console.log('1. Deleting top-level products collection...');
    const topLevelSnapshot = await db.collection('products').get();
    let deleted = 0;
    for (const doc of topLevelSnapshot.docs) {
        await db.collection('products').doc(doc.id).delete();
        deleted++;
    }
    console.log(`   ✅ Deleted ${deleted} products from top-level collection\n`);

    // 2. Delete all products from tenant subcollections
    console.log('2. Deleting products from tenant subcollections...');
    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const productsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .get();

        let tenantDeleted = 0;
        for (const doc of productsSnapshot.docs) {
            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('products')
                .doc(doc.id)
                .delete();
            tenantDeleted++;
        }
        console.log(`   ✅ Deleted ${tenantDeleted} products from tenant: ${tenantId}`);
    }

    // 3. Delete metadata flags
    console.log('\n3. Cleaning metadata...');
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
            console.log(`   ✅ Deleted metadata for tenant: ${tenantId}`);
        }
    }

    console.log('\n✅ Cleanup complete! All products have been removed.\n');
    console.log('Now restart your Flutter app and it will create fresh demo products.');
}

cleanAndResetProducts();