const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkPayments() {
    console.log('\n=== CHECKING PAYMENT RECORDS ===\n');

    // Get all payments
    const paymentsSnapshot = await db.collection('payments').get();
    console.log('Total payments in database: ' + paymentsSnapshot.size + '\n');

    for (const doc of paymentsSnapshot.docs) {
        const data = doc.data();
        const timestamp = data.timestamp ? data.timestamp.toDate() : null;
        const period = data.period ? data.period.toDate() : null;

        console.log('📝 Payment: ' + doc.id);
        console.log('   Tenant ID: ' + (data.tenantId || 'N/A'));
        console.log('   Amount: ₱' + (data.amount || 0));
        console.log('   Method: ' + (data.method || 'Cash'));
        console.log('   Timestamp: ' + (timestamp ? timestamp.toString() : 'N/A'));
        console.log('   Period: ' + (period ? period.toString() : 'N/A'));
        console.log('');
    }

    // Get all tenants and their payment status
    console.log('\n=== TENANT PAYMENT STATUS ===\n');
    const tenantsSnapshot = await db.collection('tenants').get();

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const tenantData = tenantDoc.data();
        const tenantName = tenantData.name || tenantId;

        // Find payments for this tenant
        const tenantPayments = await db
            .collection('payments')
            .where('tenantId', '==', tenantId)
            .get();

        console.log('📁 ' + tenantName);
        console.log('   Payment records: ' + tenantPayments.size);
        if (tenantPayments.size > 0) {
            const lastPayment = tenantPayments.docs[0].data();
            const lastPaymentDate = lastPayment.timestamp ? lastPayment.timestamp.toDate() : null;
            console.log('   Last payment: ' + (lastPaymentDate ? lastPaymentDate.toString() : 'N/A'));
        }
        console.log('');
    }
}

checkPayments();