const admin = require('firebase-admin');
const readline = require('readline-sync');

// Initialize Firebase Admin with service account
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function changePassword() {
    console.log('\n=== Admin Tool - Change Staff Password ===\n');

    const staffEmail = readline.question('Enter staff email: ');
    const newPassword = readline.question('Enter new password (min 6 chars): ', {
        hideEchoBack: true
    });

    if (!staffEmail || !newPassword) {
        console.log('❌ Email and password are required');
        return;
    }

    if (newPassword.length < 6) {
        console.log('❌ Password must be at least 6 characters');
        return;
    }

    try {
        // Get user by email
        const user = await admin.auth().getUserByEmail(staffEmail);

        // Update password
        await admin.auth().updateUser(user.uid, {
            password: newPassword
        });

        console.log(`\n✅ Password changed successfully for ${staffEmail}`);
        console.log(`New password: ${newPassword}`);
        console.log('\nThe staff can now login with this password.');

    } catch (error) {
        if (error.code === 'auth/user-not-found') {
            console.log(`\n❌ User not found: ${staffEmail}`);
            console.log('Make sure the user exists in Firebase Authentication.');
        } else {
            console.log(`\n❌ Error: ${error.message}`);
        }
    }
}

changePassword();