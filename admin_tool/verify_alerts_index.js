// admin_tool/verify_alerts_index.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function verifyAlertsIndex() {
    console.log('\n=== VERIFYING ALERTS INDEX ===\n');

    try {
        const alertsQuery = await admin.firestore()
            .collectionGroup('alerts')
            .where('resolved', '==', false)
            .orderBy('severity', 'desc')
            .orderBy('createdAt', 'desc')
            .limit(5)
            .get();

        console.log(`✅ Alerts index is WORKING!`);
        console.log(`   Found ${alertsQuery.size} unresolved alerts`);

        alertsQuery.forEach(doc => {
            const data = doc.data();
            console.log(`   - ${data.severity}: ${data.message?.substring(0, 50)}...`);
        });

    } catch (error) {
        console.log(`❌ Alerts index FAILED: ${error.message}`);
    }

    console.log('\n✅ Verification complete!\n');
}

verifyAlertsIndex();