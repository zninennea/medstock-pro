const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addTenantIdToProducts() {
    console.log('\n=== Adding tenantId to all products ===\n');

    try {
        // Get all products
        const productsSnapshot = await db.collection('products').get();

        if (productsSnapshot.empty) {
            console.log('No products found in the products collection.');
            return;
        }

        console.log(`Found ${productsSnapshot.size} products\n`);

        let updatedCount = 0;
        let skippedCount = 0;

        for (const doc of productsSnapshot.docs) {
            const data = doc.data();

            // Skip if tenantId already exists
            if (data.tenantId) {
                console.log(`⏭️  Skipping ${doc.id} - already has tenantId: ${data.tenantId}`);
                skippedCount++;
                continue;
            }

            // Determine tenantId based on product data or use default
            let tenantId = 'davmedical'; // default

            // You can add logic here to determine tenantId from other fields
            // For example, if you have a tenant field or based on product name
            if (data.meds && data.meds.toLowerCase().includes('cebu')) {
                tenantId = 'cebgeneral';
            }

            // Update the product with tenantId
            await doc.ref.update({
                tenantId: tenantId,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });

            console.log(`✅ Updated ${doc.id} - tenantId: ${tenantId}`);
            updatedCount++;
        }

        console.log('\n=== Summary ===');
        console.log(`✅ Updated: ${updatedCount} products`);
        console.log(`⏭️  Skipped: ${skippedCount} products (already had tenantId)`);
        console.log('✅ Done!\n');

    } catch (error) {
        console.error('❌ Error:', error);
    }
}

addTenantIdToProducts();