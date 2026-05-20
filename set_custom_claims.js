// set_custom_claims.js
const admin = require('firebase-admin');

// Initialize with application default credentials
admin.initializeApp({
    projectId: 'medstock-fa87e'
});

async function createUserAndSetClaims(email, password, role, tenantId) {
    try {
        // Try to get existing user
        let userRecord;
        try {
            userRecord = await admin.auth().getUserByEmail(email);
            console.log(`User already exists: ${email}`);
        } catch (error) {
            // User doesn't exist, create them
            if (error.code === 'auth/user-not-found') {
                userRecord = await admin.auth().createUser({
                    email: email,
                    password: password,
                    emailVerified: true,
                });
                console.log(`✅ User created: ${email}`);
            } else {
                throw error;
            }
        }

        // Set custom claims
        const claims = {
            role: role,
            tenantId: tenantId,
        };
        await admin.auth().setCustomUserClaims(userRecord.uid, claims);
        console.log(`✅ Claims set for ${email}:`, claims);
    } catch (error) {
        console.error(`❌ Error for ${email}:`, error.message);
    }
}

async function setupUsers() {
    const users = [
        { email: 'superadmin@medstock.pro', password: 'super123', role: 'superAdmin', tenantId: null },
        { email: 'admin@davmedical.com', password: 'admin123', role: 'admin', tenantId: 'davmedical' },
        { email: 'admin@cebgeneral.com', password: 'admin123', role: 'admin', tenantId: 'cebgeneral' },
        { email: 'maria.santos@davmedical.com', password: 'staff123', role: 'staff', tenantId: 'davmedical' },
        { email: 'jun.reyes@davmedical.com', password: 'staff123', role: 'staff', tenantId: 'davmedical' },
    ];

    for (const user of users) {
        await createUserAndSetClaims(user.email, user.password, user.role, user.tenantId);
    }

    console.log('\n✅ All users setup complete!');
    process.exit();
}

setupUsers();