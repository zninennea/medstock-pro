// admin_tool/verify_products.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyProducts() {
    console.log('\n=== Verifying Product Locations ===\n');

    // Check tenants subcollection
    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        console.log(`\n📁 Tenant: ${tenantId}`);

        const productsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .get();

        console.log(`   Products in subcollection: ${productsSnapshot.size}`);

        for (const doc of productsSnapshot.docs) {
            const data = doc.data();
            console.log(`   - ${doc.id}: ${data.meds} (Qty: ${data.qty})`);
        }
    }

    // Check old top-level collection
    const oldProductsSnapshot = await db.collection('products').get();
    console.log(`\n📁 Old top-level products collection: ${oldProductsSnapshot.size} products`);

    if (oldProductsSnapshot.size > 0) {
        console.log('   ⚠️ These products are NOT being used by the app anymore.');
        console.log('   Consider deleting them after confirming migration.');
    }

    console.log('\n✅ Verification complete!\n');
}

verifyProducts();