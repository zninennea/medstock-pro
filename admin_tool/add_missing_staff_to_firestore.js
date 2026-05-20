// admin_tool/add_missing_staff_to_firestore.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addMissingStaffToFirestore() {
    console.log('\n=== Adding Missing Staff to Firestore ===\n');

    // Staff that need to be added to Firestore
    const missingStaff = [{
            email: 'maria.santos@davmedical.com',
            name: 'Maria Santos',
            tenantId: 'davmedical',
            role: 'staff',
            createdBy: 'admin@davmedical.com'
        },
        {
            email: 'jun.reyes@davmedical.com',
            name: 'Jun Reyes',
            tenantId: 'davmedical',
            role: 'staff',
            createdBy: 'admin@davmedical.com'
        }
    ];

    for (const staff of missingStaff) {
        console.log(`📝 Processing: ${staff.email}`);

        try {
            // 1. Add to global users collection
            const userData = {
                email: staff.email,
                name: staff.name,
                role: staff.role,
                tenantId: staff.tenantId,
                createdBy: staff.createdBy,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            };

            await db.collection('users').doc(staff.email).set(userData);
            console.log(`   ✅ Added to users collection`);

            // 2. Add to tenant staff subcollection
            await db
                .collection('tenants')
                .doc(staff.tenantId)
                .collection('staff')
                .doc(staff.email)
                .set(userData);
            console.log(`   ✅ Added to tenants/${staff.tenantId}/staff`);

            // 3. Verify custom claims are correct
            const user = await admin.auth().getUserByEmail(staff.email);
            const claims = user.customClaims || {};

            if (claims.role !== 'staff' || claims.tenantId !== staff.tenantId) {
                console.log(`   🔧 Fixing custom claims...`);
                await admin.auth().setCustomUserClaims(user.uid, {
                    role: 'staff',
                    tenantId: staff.tenantId
                });
                console.log(`   ✅ Custom claims updated`);
            } else {
                console.log(`   ✅ Custom claims already correct`);
            }

            console.log(`   ✅ Complete for ${staff.email}\n`);

        } catch (error) {
            console.log(`   ❌ Error: ${error.message}\n`);
        }
    }

    console.log('✅ All missing staff added!\n');
}

addMissingStaffToFirestore();