// admin_tool/cleanup_duplicate_products.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function cleanupDuplicateProducts() {
    console.log('\n=== CLEANING UP DUPLICATE PRODUCTS ===\n');

    // Get all tenants
    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        console.log(`\n📁 Processing tenant: ${tenantId}`);

        // Get all products for this tenant
        const productsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .get();

        const uniqueLotNumbers = new Map();
        const duplicates = [];

        // Find duplicates by lot number
        for (const doc of productsSnapshot.docs) {
            const data = doc.data();
            const lotNumber = data.lotNumber;

            if (uniqueLotNumbers.has(lotNumber)) {
                duplicates.push({
                    id: doc.id,
                    lotNumber: lotNumber,
                    existingId: uniqueLotNumbers.get(lotNumber)
                });
                console.log(`   ⚠️ Duplicate found: ${doc.id} (Lot: ${lotNumber})`);
            } else {
                uniqueLotNumbers.set(lotNumber, doc.id);
            }
        }

        // Delete duplicates
        for (const dup of duplicates) {
            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('products')
                .doc(dup.id)
                .delete();
            console.log(`   ✅ Deleted duplicate: ${dup.id}`);
        }

        if (duplicates.length === 0) {
            console.log(`   ✅ No duplicates found in ${tenantId}`);
        } else {
            console.log(`   📊 Deleted ${duplicates.length} duplicate products`);
        }
    }

    console.log('\n✅ Cleanup complete!\n');
}

cleanupDuplicateProducts();