// admin_tool/add_missing_staff_manual.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addMissingStaff() {
    console.log('\n=== ADDING MISSING STAFF TO FIRESTORE ===\n');

    const staffList = [
        { email: 'analie@gmail.com', name: 'Analie', tenantId: 'evez_pharma' },
        { email: 'miguelbacay123@gmail.com', name: 'Miguel Bacay', tenantId: 'evez_pharma' }
    ];

    for (const staff of staffList) {
        try {
            // Add to users collection
            await db.collection('users').doc(staff.email).set({
                email: staff.email,
                name: staff.name,
                role: 'staff',
                tenantId: staff.tenantId,
                createdBy: 'admin@evez_pharma',
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`✅ Added to users: ${staff.email}`);

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
                    createdBy: 'admin@evez_pharma'
                });
            console.log(`✅ Added to tenants/${staff.tenantId}/staff: ${staff.email}`);

        } catch (error) {
            console.log(`❌ Error for ${staff.email}: ${error.message}`);
        }
    }

    console.log('\n✅ Complete!\n');
}

addMissingStaff();