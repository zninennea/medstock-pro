// admin_tool/check_indexes.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function checkIndexes() {
    console.log('\n=== CHECKING EXISTING INDEXES ===\n');

    // This will list indexes from the console
    // You need to check manually in Firebase Console > Indexes tab

    console.log('Go to Firebase Console → Firestore → Indexes tab');
    console.log('Look for:');
    console.log('1. payments - composite index (tenantId, timestamp)');
    console.log('2. alerts - composite index (resolved, severity, createdAt)');
    console.log('\nIf missing, create them using the instructions above.');
}

checkIndexes();