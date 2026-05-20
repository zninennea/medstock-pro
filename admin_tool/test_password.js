const admin = require('firebase-admin');
const readline = require('readline-sync');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function testPassword() {
    console.log('\n=== Test Staff Password ===\n');

    const email = readline.question('Enter staff email to test: ');
    const password = readline.question('Enter password to test: ', {
        hideEchoBack: true
    });

    console.log(`\nTesting login for: ${email}`);

    try {
        // Try to get user - this will fail if user doesn't exist
        const user = await admin.auth().getUserByEmail(email);
        console.log(`✅ User exists: ${user.uid}`);
        console.log(`   Custom claims:`, user.customClaims || {});

        console.log(`\n⚠️ Note: Cannot test actual password sign-in from Admin SDK.`);
        console.log(`Please try logging into the Flutter app with:`);
        console.log(`   Email: ${email}`);
        console.log(`   Password: ${password}`);

    } catch (error) {
        console.log(`❌ User not found: ${error.message}`);
    }
}

testPassword();