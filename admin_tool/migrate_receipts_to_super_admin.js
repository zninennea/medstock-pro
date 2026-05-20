const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateReceiptsToSuperAdmin() {
    console.log('\n=== Migrating Receipts to Super Admin Collection ===\n');

    // Get all tenants
    const tenantsSnapshot = await db.collection('tenants').get();
    console.log('Found ' + tenantsSnapshot.size + ' tenants\n');

    // Ensure super admin document exists
    const superAdminRef = db.collection('superAdmin').doc('superadmin');
    const superAdminDoc = await superAdminRef.get();
    if (!superAdminDoc.exists) {
        await superAdminRef.set({
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system',
            role: 'superAdmin',
        });
        console.log('✅ Created super admin document\n');
    }

    let totalMigrated = 0;
    let totalSkipped = 0;

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const tenantData = tenantDoc.data();
        const tenantName = tenantData.name || tenantId;

        console.log('📁 Processing tenant: ' + tenantName + ' (' + tenantId + ')');

        // Get all receipts from tenant's receipts subcollection
        const receiptsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('receipts')
            .get();

        console.log('   Found ' + receiptsSnapshot.size + ' receipts');

        let tenantMigrated = 0;

        for (const receiptDoc of receiptsSnapshot.docs) {
            const receiptData = receiptDoc.data();
            const receiptId = receiptDoc.id;

            // Check if receipt already exists in super admin collection
            const existingReceipt = await superAdminRef
                .collection('receipts')
                .doc(receiptId)
                .get();

            if (existingReceipt.exists) {
                console.log('   ⏭️ Receipt ' + receiptId + ' already exists in super admin');
                totalSkipped++;
                continue;
            }

            // Get payment data if available
            let paymentData = null;
            if (receiptData.paymentReference) {
                const paymentSnapshot = await db
                    .collection('payments')
                    .where('reference', '==', receiptData.paymentReference)
                    .limit(1)
                    .get();

                if (!paymentSnapshot.empty) {
                    paymentData = paymentSnapshot.docs[0].data();
                }
            }

            // Prepare receipt data for super admin
            const superAdminReceiptData = {
                receiptId: receiptId,
                tenantId: tenantId,
                tenantName: tenantName,
                amount: receiptData.amount || (paymentData ? paymentData.amount : 0) || 0,
                method: receiptData.method || (paymentData ? paymentData.method : 'Cash') || 'Cash',
                reference: receiptData.paymentReference || (paymentData ? paymentData.reference : 'N/A') || 'N/A',
                receiptData: receiptData.receiptData || '',
                createdAt: receiptData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
                uploadedBy: receiptData.uploadedBy || 'system',
                verified: receiptData.verified || false,
                verifiedAt: receiptData.verifiedAt || null,
                verifiedBy: receiptData.verifiedBy || null,
            };

            // Save to super admin collection
            await superAdminRef
                .collection('receipts')
                .doc(receiptId)
                .set(superAdminReceiptData);

            tenantMigrated++;
            totalMigrated++;
            console.log('   ✅ Migrated receipt: ' + receiptId);
        }

        console.log('   📊 Migrated ' + tenantMigrated + ' receipts from ' + tenantName + '\n');
    }

    // Also check payments collection for receipts that might not be in tenant receipts subcollection
    console.log('📁 Checking payments collection for additional receipts...');

    const paymentsSnapshot = await db.collection('payments').get();
    console.log('   Found ' + paymentsSnapshot.size + ' payments');

    let paymentReceiptsMigrated = 0;

    for (const paymentDoc of paymentsSnapshot.docs) {
        const paymentData = paymentDoc.data();
        const paymentId = paymentDoc.id;
        const tenantId = paymentData.tenantId;
        const receiptId = paymentData.receiptId || ('receipt_from_payment_' + paymentId);

        // Skip if no receipt data
        if (!paymentData.receiptData && !paymentData.receiptUrl) {
            continue;
        }

        // Check if already in super admin
        const existingReceipt = await superAdminRef
            .collection('receipts')
            .doc(receiptId)
            .get();

        if (existingReceipt.exists) {
            continue;
        }

        // Get tenant name
        let tenantName = tenantId;
        const tenantDoc = await db.collection('tenants').doc(tenantId).get();
        if (tenantDoc.exists) {
            const tenantData = tenantDoc.data();
            tenantName = tenantData ? (tenantData.name || tenantId) : tenantId;
        }

        const superAdminReceiptData = {
            receiptId: receiptId,
            tenantId: tenantId,
            tenantName: tenantName,
            amount: paymentData.amount || 0,
            method: paymentData.method || 'Cash',
            reference: paymentData.reference || 'N/A',
            receiptData: paymentData.receiptData || '',
            createdAt: paymentData.timestamp || admin.firestore.FieldValue.serverTimestamp(),
            uploadedBy: paymentData.recordedBy || 'system',
            verified: paymentData.isVerified || false,
            verifiedAt: paymentData.isVerified ? paymentData.timestamp : null,
            verifiedBy: paymentData.verifiedBy || null,
        };

        await superAdminRef
            .collection('receipts')
            .doc(receiptId)
            .set(superAdminReceiptData);

        paymentReceiptsMigrated++;
        console.log('   ✅ Migrated receipt from payment: ' + receiptId);
    }

    console.log('\n========================================');
    console.log('✅ MIGRATION COMPLETE');
    console.log('========================================');
    console.log('📊 Total receipts migrated from tenants: ' + totalMigrated);
    console.log('📊 Total receipts migrated from payments: ' + paymentReceiptsMigrated);
    console.log('📊 Total receipts skipped (already exist): ' + totalSkipped);
    console.log('========================================\n');

    // Verify migration
    console.log('Verifying migration...');
    const finalReceiptsCount = await superAdminRef.collection('receipts').get();
    console.log('📊 Total receipts in super admin collection: ' + finalReceiptsCount.size);
}

// Run the migration
migrateReceiptsToSuperAdmin()
    .then(function() {
        console.log('Migration completed successfully!');
        process.exit(0);
    })
    .catch(function(error) {
        console.error('Error:', error);
        process.exit(1);
    });