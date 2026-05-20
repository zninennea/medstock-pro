// admin_tool/cleanup_duplicates.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function cleanupDuplicates() {
    console.log('\n=== Cleaning Up Duplicate Transactions and Audit Entries ===\n');

    const tenants = ['davmedical', 'cebgeneral', 'med_cares'];

    for (const tenantId of tenants) {
        console.log(`\n📁 Processing tenant: ${tenantId}`);

        // Clean up duplicate transactions
        const transactionsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('transactions')
            .get();

        const seenTransactionIds = new Set();
        const duplicateTransactions = [];

        for (const doc of transactionsSnapshot.docs) {
            if (seenTransactionIds.has(doc.id)) {
                duplicateTransactions.push(doc);
                console.log(`   Found duplicate transaction: ${doc.id}`);
            } else {
                seenTransactionIds.add(doc.id);
            }
        }

        for (const dup of duplicateTransactions) {
            await dup.ref.delete();
            console.log(`   ✅ Deleted duplicate transaction: ${dup.id}`);
        }

        // Clean up duplicate audit entries
        const auditSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('audit')
            .get();

        const seenAuditKeys = new Set();
        const duplicateAudits = [];

        for (const doc of auditSnapshot.docs) {
            const data = doc.data();
            const key = `${data.action}_${data.details}_${data.timestamp}`;

            if (seenAuditKeys.has(key)) {
                duplicateAudits.push(doc);
                console.log(`   Found duplicate audit: ${doc.id}`);
            } else {
                seenAuditKeys.add(key);
            }
        }

        for (const dup of duplicateAudits) {
            await dup.ref.delete();
            console.log(`   ✅ Deleted duplicate audit: ${dup.id}`);
        }

        console.log(`   ✅ ${tenantId} cleanup complete - Removed ${duplicateTransactions.length} duplicate transactions, ${duplicateAudits.length} duplicate audits`);
    }

    console.log('\n✅ Cleanup complete!\n');
}

cleanupDuplicates();