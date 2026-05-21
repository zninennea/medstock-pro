// admin_tool/fix_missing_staff.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixMissingStaff() {
    console.log('\n=== FIXING MISSING STAFF IN FIRESTORE ===\n');

    // List of staff that were created in Auth but missing in Firestore
    const missingStaff = [
        { email: 'analie@gmail.com', name: 'Analie', tenantId: 'evez_pharma' },
        { email: 'miguelbacay123@gmail.com', name: 'Miguel Bacay', tenantId: 'evez_pharma' }
    ];

    for (const staff of missingStaff) {
        try {
            // Check if user exists in Firebase Auth
            const user = await admin.auth().getUserByEmail(staff.email);
            console.log(`✅ User exists in Auth: ${staff.email}`);

            // Add to users collection
            await db.collection('users').doc(staff.email).set({
                email: staff.email,
                name: staff.name,
                role: 'staff',
                tenantId: staff.tenantId,
                createdBy: 'system_fix',
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`✅ Added to users collection: ${staff.email}`);

            // Add to tenant staff subcollection
            await db
                .collection('tenants')
                .doc(staff.tenantId)
                .collection('staff')
                .doc(staff.email)
                .set({
                    email: staff.email,
                    name: staff.name,
                    role: 'staff',
                    tenantId: staff.tenantId,
                    createdBy: 'system_fix'
                });
            console.log(`✅ Added to tenants/${staff.tenantId}/staff: ${staff.email}`);

        } catch (error) {
            console.log(`❌ Error for ${staff.email}: ${error.message}`);
        }
    }

    console.log('\n✅ Fix complete!\n');
}

fixMissingStaff();