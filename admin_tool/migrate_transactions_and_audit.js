const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');
const readline = require('readline-sync');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateTransactionsAndAudit() {
    console.log('\n========================================');
    console.log('🔄 MIGRATING TRANSACTIONS & AUDIT TRAILS');
    console.log('========================================\n');

    // Get all tenants
    const tenantsSnapshot = await db.collection('tenants').get();
    console.log('Found ' + tenantsSnapshot.size + ' tenants\n');

    let totalTransactionsMigrated = 0;
    let totalAuditMigrated = 0;

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const tenantData = tenantDoc.data();
        const tenantName = tenantData.name || tenantId;

        console.log('\n📁 Processing tenant: ' + tenantName + ' (' + tenantId + ')');
        console.log('─'.repeat(50));

        // ============================================
        // 1. MIGRATE TRANSACTIONS
        // ============================================
        console.log('\n📊 Checking transactions...');

        // Check if transactions exist in old location (top-level transactions collection)
        const oldTransactionsSnapshot = await db
            .collection('transactions')
            .where('tenantId', '==', tenantId)
            .get();

        console.log('   Found ' + oldTransactionsSnapshot.size + ' transactions in old collection');

        let tenantTransactionsMigrated = 0;

        for (const doc of oldTransactionsSnapshot.docs) {
            const data = doc.data();
            const transactionId = doc.id;

            // Check if already in tenant subcollection
            const existingTransaction = await db
                .collection('tenants')
                .doc(tenantId)
                .collection('transactions')
                .doc(transactionId)
                .get();

            if (existingTransaction.exists) {
                console.log('   ⏭️ Transaction already exists: ' + transactionId);
                continue;
            }

            // Migrate to tenant subcollection
            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('transactions')
                .doc(transactionId)
                .set({
                    ...data,
                    migratedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

            tenantTransactionsMigrated++;
            console.log('   ✅ Migrated transaction: ' + transactionId);
        }

        totalTransactionsMigrated += tenantTransactionsMigrated;
        console.log('   📊 Migrated ' + tenantTransactionsMigrated + ' transactions for ' + tenantName);

        // ============================================
        // 2. CHECK TRANSACTIONS IN PRODUCT PROVIDER
        // ============================================
        console.log('\n📦 Checking product transactions...');

        const productsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .get();

        let productTransactionCount = 0;
        for (const productDoc of productsSnapshot.docs) {
            const productData = productDoc.data();
            // You might have transactions stored with products
            if (productData.transactions) {
                productTransactionCount += productData.transactions.length;
            }
        }
        console.log('   Found ' + productTransactionCount + ' product-related transactions');

        // ============================================
        // 3. MIGRATE AUDIT TRAILS
        // ============================================
        console.log('\n📋 Checking audit trails...');

        // Check if audit entries exist in old location (top-level audit collection)
        const oldAuditSnapshot = await db
            .collection('audit')
            .where('tenantId', '==', tenantId)
            .get();

        console.log('   Found ' + oldAuditSnapshot.size + ' audit entries in old collection');

        let tenantAuditMigrated = 0;

        for (const doc of oldAuditSnapshot.docs) {
            const data = doc.data();
            const auditId = doc.id;

            // Check if already in tenant subcollection
            const existingAudit = await db
                .collection('tenants')
                .doc(tenantId)
                .collection('audit')
                .doc(auditId)
                .get();

            if (existingAudit.exists) {
                console.log('   ⏭️ Audit entry already exists: ' + auditId);
                continue;
            }

            // Migrate to tenant subcollection
            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('audit')
                .doc(auditId)
                .set({
                    ...data,
                    migratedAt: admin.firestore.FieldValue.serverTimestamp(),
                });

            tenantAuditMigrated++;
            console.log('   ✅ Migrated audit entry: ' + auditId);
        }

        totalAuditMigrated += tenantAuditMigrated;
        console.log('   📊 Migrated ' + tenantAuditMigrated + ' audit entries for ' + tenantName);

        // ============================================
        // 4. VERIFY FINAL COUNTS
        // ============================================
        console.log('\n✅ Verifying final counts...');

        const finalTransactionsCount = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('transactions')
            .get();

        const finalAuditCount = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('audit')
            .get();

        console.log('   📊 Final transactions count: ' + finalTransactionsCount.size);
        console.log('   📊 Final audit entries count: ' + finalAuditCount.size);
    }

    // ============================================
    // 5. SUMMARY
    // ============================================
    console.log('\n========================================');
    console.log('✅ MIGRATION COMPLETE');
    console.log('========================================');
    console.log('📊 Total transactions migrated: ' + totalTransactionsMigrated);
    console.log('📊 Total audit entries migrated: ' + totalAuditMigrated);
    console.log('========================================\n');

    console.log('📋 Next steps:');
    console.log('1. Restart your Flutter app');
    console.log('2. Check Transaction screen for history');
    console.log('3. Check Audit Trail screen for entries\n');
}

// Function to create test transactions if none exist
async function createTestTransactions() {
    console.log('\n========================================');
    console.log('🧪 CREATING TEST TRANSACTIONS');
    console.log('========================================\n');

    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const productsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .limit(2)
            .get();

        if (productsSnapshot.empty) {
            console.log('⚠️ No products found for tenant: ' + tenantId + ', skipping test transactions');
            continue;
        }

        console.log('\n📁 Creating test transactions for tenant: ' + tenantId);

        for (const productDoc of productsSnapshot.docs) {
            const productData = productDoc.data();
            const transactionId = 'test_' + Date.now() + '_' + productDoc.id;

            // Create a test stock in transaction
            const stockInTransaction = {
                id: transactionId + '_in',
                productId: productDoc.id,
                productName: productData.meds,
                lotNumber: productData.lotNumber,
                type: 'in',
                qty: 10,
                reason: 'Test Restock (Migration)',
                reference: 'MIG-' + Date.now(),
                staffId: 'system',
                staffName: 'System Migration',
                timestamp: admin.firestore.Timestamp.fromDate(new Date()),
                balAfter: (productData.qty || 0) + 10,
                tenantId: tenantId,
                productDetails: {
                    meds: productData.meds,
                    brand: productData.brand,
                    uom: productData.uom,
                },
            };

            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('transactions')
                .doc(stockInTransaction.id)
                .set(stockInTransaction);

            console.log('   ✅ Created test stock in for: ' + productData.meds);

            // Create test audit entry
            const auditId = 'audit_' + Date.now() + '_' + productDoc.id;
            const auditEntry = {
                timestamp: new Date().toISOString(),
                action: 'Stock In (Test)',
                details: 'Test transaction: Restocked 10 units of ' + productData.meds,
                user: 'System Migration',
                role: 'superAdmin',
            };

            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('audit')
                .doc(auditId)
                .set(auditEntry);

            console.log('   ✅ Created test audit entry for: ' + productData.meds);
        }
    }

    console.log('\n✅ Test transactions created!\n');
}

// Function to verify data is visible
async function verifyData() {
    console.log('\n========================================');
    console.log('🔍 VERIFYING DATA');
    console.log('========================================\n');

    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const tenantData = tenantDoc.data();
        const tenantName = tenantData.name || tenantId;

        console.log('\n📁 Tenant: ' + tenantName + ' (' + tenantId + ')');

        const transactionsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('transactions')
            .orderBy('timestamp', 'desc')
            .limit(5)
            .get();

        console.log('   📊 Recent transactions (' + transactionsSnapshot.size + '):');
        for (const doc of transactionsSnapshot.docs) {
            const data = doc.data();
            const date = data.timestamp ? data.timestamp.toDate() : new Date();
            const typeIcon = data.type === 'in' ? '📥 Stock In' : '📤 Stock Out';
            console.log('      - ' + date.toISOString().split('T')[0] + ': ' + typeIcon + ' - ' + data.productName + ' (' + data.qty + ' units)');
        }

        const auditSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('audit')
            .orderBy('timestamp', 'desc')
            .limit(5)
            .get();

        console.log('   📋 Recent audit entries (' + auditSnapshot.size + '):');
        for (const doc of auditSnapshot.docs) {
            const data = doc.data();
            const date = data.timestamp ? new Date(data.timestamp) : new Date();
            const detailsPreview = data.details ? data.details.substring(0, 50) : '';
            console.log('      - ' + date.toISOString().split('T')[0] + ': ' + data.action + ' - ' + detailsPreview + '...');
        }
    }

    console.log('\n✅ Verification complete!\n');
}

// Run all functions
async function main() {
    // First, migrate existing data
    await migrateTransactionsAndAudit();

    // Then, create test transactions if needed
    const createTest = readline.question('\nDo you want to create test transactions? (y/n): ');

    if (createTest.toLowerCase() === 'y') {
        await createTestTransactions();
    }

    // Verify the data
    await verifyData();

    console.log('\n✅ All done! Restart your Flutter app to see the changes.\n');
    process.exit(0);
}

main();