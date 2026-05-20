// admin_tool/create_super_admin_receipts_collection.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createSuperAdminReceiptsCollection() {
    console.log('\n=== Creating Super Admin Receipts Collection ===\n');

    const superAdminRef = db.collection('superAdmin').doc('superadmin');
    const superAdminDoc = await superAdminRef.get();

    if (!superAdminDoc.exists) {
        await superAdminRef.set({
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system',
            role: 'superAdmin',
        });
        console.log('✅ Super Admin document created');
    } else {
        console.log('ℹ️ Super Admin document already exists');
    }

    // Create receipts subcollection (by adding a dummy receipt if needed)
    const receiptsSnapshot = await superAdminRef.collection('receipts').limit(1).get();
    if (receiptsSnapshot.empty) {
        console.log('ℹ️ Receipts subcollection is empty, ready for new receipts');
    }

    console.log('\n✅ Setup complete!');
}

createSuperAdminReceiptsCollection();