// admin_tool/diagnose_indexes.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function diagnoseIndexes() {
    console.log('\n=== DIAGNOSING FIRESTORE INDEXES ===\n');

    // 1. Check what indexes exist
    console.log('1. CHECKING EXISTING INDEXES:');
    console.log('   Go to Firebase Console → Firestore → Indexes tab');
    console.log('   Look for composite indexes.\n');

    // 2. Test each query that might need an index
    console.log('2. TESTING QUERIES:\n');

    // Test 1: Payments query (needs index if it fails)
    console.log('   Testing payments query...');
    try {
        const testPayment = await admin.firestore()
            .collection('payments')
            .orderBy('timestamp', 'desc')
            .limit(1)
            .get();
        console.log('   ✅ Payments query: SUCCESS (no index needed or index exists)');
    } catch (error) {
        if (error.message.includes('index')) {
            console.log('   ❌ Payments query: NEEDS INDEX');
            console.log('   Create index: tenantId (ASC), timestamp (DESC)');
        } else {
            console.log(`   ⚠️ Payments query: Other error - ${error.message}`);
        }
    }

    // Test 2: Alerts query (composite - likely needs index)
    console.log('\n   Testing alerts query...');
    try {
        const testAlert = await admin.firestore()
            .collectionGroup('alerts')
            .where('resolved', '==', false)
            .orderBy('severity', 'desc')
            .orderBy('createdAt', 'desc')
            .limit(1)
            .get();
        console.log('   ✅ Alerts query: SUCCESS (index exists)');
    } catch (error) {
        if (error.message.includes('index')) {
            console.log('   ❌ Alerts query: NEEDS INDEX');
            console.log('   Create index: resolved (ASC), severity (DESC), createdAt (DESC)');
            console.log(`   Error: ${error.message}`);
        } else {
            console.log(`   ⚠️ Alerts query: Other error - ${error.message}`);
        }
    }

    // Test 3: Check if alerts subcollection exists
    console.log('\n   Checking if alerts collection has data...');
    const tenants = await admin.firestore().collection('tenants').limit(1).get();
    if (!tenants.empty) {
        const firstTenant = tenants.docs[0].id;
        const alertsSnapshot = await admin.firestore()
            .collection('tenants')
            .doc(firstTenant)
            .collection('alerts')
            .limit(1)
            .get();

        if (alertsSnapshot.empty) {
            console.log('   ⚠️ No alerts data found. Create some alerts first to test the query.');
        } else {
            console.log('   ✅ Alerts data exists');
        }
    }

    console.log('\n3. WHAT TO DO:');
    console.log('   - If queries passed: No indexes needed!');
    console.log('   - If queries failed with index error: Create the index using the link in the error');
    console.log('   - If no errors: Your app is working fine!\n');
}

diagnoseIndexes();