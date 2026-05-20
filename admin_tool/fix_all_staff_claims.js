// admin_tool/fix_all_staff_claims.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function fixAllStaffClaims() {
    console.log('\n=== Fixing Custom Claims for All Staff ===\n');

    // Get all users from Firebase Auth
    const listUsersResult = await admin.auth().listUsers(1000);

    console.log(`Found ${listUsersResult.users.length} total users\n`);

    let fixedCount = 0;
    let skippedCount = 0;

    for (const user of listUsersResult.users) {
        const email = user.email;
        if (!email) continue;

        const claims = user.customClaims || {};
        const currentRole = claims.role;
        const currentTenantId = claims.tenantId;

        // Determine if this should be a staff account
        let shouldBeStaff = false;
        let tenantId = null;

        // Check in Firestore users collection
        const userDoc = await db.collection('users').doc(email.toLowerCase()).get();
        if (userDoc.exists) {
            const userData = userDoc.data();
            if (userData && userData.role === 'staff') {
                shouldBeStaff = true;
                tenantId = userData.tenantId;
            }
        }

        // Also check in tenant staff subcollections
        if (!shouldBeStaff) {
            const tenantsSnapshot = await db.collection('tenants').get();
            for (const tenantDoc of tenantsSnapshot.docs) {
                const staffDoc = await db
                    .collection('tenants')
                    .doc(tenantDoc.id)
                    .collection('staff')
                    .doc(email.toLowerCase())
                    .get();

                if (staffDoc.exists) {
                    shouldBeStaff = true;
                    tenantId = tenantDoc.id;
                    break;
                }
            }
        }

        if (shouldBeStaff) {
            if (currentRole !== 'staff' || currentTenantId !== tenantId) {
                console.log(`🔧 Fixing ${email}`);
                console.log(`   Current: role=${currentRole || 'none'}, tenantId=${currentTenantId || 'none'}`);
                console.log(`   Expected: role=staff, tenantId=${tenantId}`);

                await admin.auth().setCustomUserClaims(user.uid, {
                    role: 'staff',
                    tenantId: tenantId
                });

                console.log(`   ✅ Fixed!\n`);
                fixedCount++;
            } else {
                console.log(`✅ Already correct: ${email} (staff, ${tenantId})\n`);
                skippedCount++;
            }
        } else if (currentRole === 'staff') {
            // User has staff role but shouldn't - this is suspicious
            console.log(`⚠️ User ${email} has staff role but not found in staff collections\n`);
        }
    }

    console.log(`\n=== Summary ===`);
    console.log(`✅ Fixed: ${fixedCount} staff accounts`);
    console.log(`⏭️ Skipped: ${skippedCount} already correct`);
    console.log(`\n✅ Complete!`);
}

fixAllStaffClaims();