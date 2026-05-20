// create_users.js
const admin = require('firebase-admin');

// Initialize with application default credentials
admin.initializeApp({
    projectId: 'medstock-fa87e'
});

async function createUser(email, password) {
    try {
        const userRecord = await admin.auth().createUser({
            email: email,
            password: password,
            emailVerified: true,
        });
        console.log(`✅ User created: ${email} (UID: ${userRecord.uid})`);
        return userRecord;
    } catch (error) {
        if (error.code === 'auth/email-already-exists') {
            console.log(`User already exists: ${email}`);
            return await admin.auth().getUserByEmail(email);
        } else {
            console.error(`❌ Error creating ${email}:`, error.message);
            return null;
        }
    }
}

async function setClaims(uid, role, tenantId) {
    try {
        const claims = {
            role: role,
            tenantId: tenantId,
        };
        await admin.auth().setCustomUserClaims(uid, claims);
        console.log(`✅ Claims set for ${uid}:`, claims);
    } catch (error) {
        console.error(`❌ Error setting claims:`, error.message);
    }
}

async function setup() {
    console.log('Creating users...\n');

    // Create users
    const superAdmin = await createUser('superadmin@medstock.pro', 'super123');
    const admin1 = await createUser('admin@davmedical.com', 'admin123');
    const admin2 = await createUser('admin@cebgeneral.com', 'admin123');
    const staff1 = await createUser('maria.santos@davmedical.com', 'staff123');
    const staff2 = await createUser('jun.reyes@davmedical.com', 'staff123');

    console.log('\nSetting custom claims...\n');

    // Set claims
    if (superAdmin) await setClaims(superAdmin.uid, 'superAdmin', null);
    if (admin1) await setClaims(admin1.uid, 'admin', 'davmedical');
    if (admin2) await setClaims(admin2.uid, 'admin', 'cebgeneral');
    if (staff1) await setClaims(staff1.uid, 'staff', 'davmedical');
    if (staff2) await setClaims(staff2.uid, 'staff', 'davmedical');

    console.log('\n✅ Setup complete! You can now login with:');
    console.log('Super Admin: superadmin@medstock.pro / super123');
    console.log('Davao Admin: admin@davmedical.com / admin123');
    console.log('Cebu Admin: admin@cebgeneral.com / admin123');
    console.log('Staff: maria.santos@davmedical.com / staff123');
    console.log('Staff: jun.reyes@davmedical.com / staff123');

    process.exit();
}

setup();