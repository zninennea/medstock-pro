// admin_tool/calculate_arr.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function calculateARR() {
    console.log('\n=== ARR Calculation ===\n');

    const tenantsSnapshot = await db.collection('tenants').get();
    let totalARR = 0;

    console.log('Tenant Breakdown:');
    console.log('─'.repeat(50));

    for (const doc of tenantsSnapshot.docs) {
        const data = doc.data();
        const name = data.name || doc.id;
        const monthlyBilling = data.billing || 0;
        const annual = monthlyBilling * 12;
        const isSuspended = data.suspended || false;

        totalARR += annual;

        console.log(`${name}:`);
        console.log(`  Monthly: ₱${monthlyBilling.toLocaleString()}`);
        console.log(`  Annual:  ₱${annual.toLocaleString()}`);
        console.log(`  Status:  ${isSuspended ? 'SUSPENDED' : 'ACTIVE'}`);
        console.log('');
    }

    console.log('─'.repeat(50));
    console.log(`TOTAL ARR: ₱${totalARR.toLocaleString()}`);
    console.log('========================================\n');
}

calculateARR();