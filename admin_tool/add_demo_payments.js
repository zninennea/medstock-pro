// admin_tool/add_demo_payments.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addDemoPayments() {
    console.log('\n=== Adding Demo Payment Records ===\n');

    const tenants = [
        { id: 'davmedical', name: 'Davao Medical Center', billing: 4500 },
        { id: 'cebgeneral', name: 'Cebu General Hospital', billing: 12500 }
    ];

    const now = new Date();
    const currentPeriod = new Date(now.getFullYear(), now.getMonth(), 1);

    for (const tenant of tenants) {
        // Check if payment already exists
        const existingPayments = await db
            .collection('payments')
            .where('tenantId', '==', tenant.id)
            .limit(1)
            .get();

        if (!existingPayments.empty) {
            console.log(`⏭️ Tenant ${tenant.id} already has payment records. Skipping...`);
            continue;
        }

        const reference = `INV-DEMO-${tenant.id}-${Date.now()}`;

        await db.collection('payments').add({
            tenantId: tenant.id,
            tenantName: tenant.name,
            date: admin.firestore.Timestamp.fromDate(now),
            amount: tenant.billing,
            receiptUrl: '',
            receiptData: null,
            method: 'Cash',
            period: admin.firestore.Timestamp.fromDate(currentPeriod),
            reference: reference,
            isVerified: true,
            timestamp: admin.firestore.Timestamp.fromDate(now),
            recordedBy: 'System (Demo Data)',
            note: 'Initial payment for demo tenant'
        });

        console.log(`✅ Added payment for ${tenant.name} (${tenant.id})`);
    }

    console.log('\n✅ Demo payments added successfully!\n');
}

addDemoPayments();