// admin_tool/remove_passwords_from_firestore.js
const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function removePasswords() {
    console.log('\n=== REMOVING PASSWORDS FROM USERS COLLECTION ===\n');

    const usersSnapshot = await db.collection('users').get();

    for (const doc of usersSnapshot.docs) {
        const data = doc.data();

        if (data.password) {
            console.log(`Removing password from: ${doc.id}`);
            await db.collection('users').doc(doc.id).update({
                'password': admin.firestore.FieldValue.delete()
            });
        }
    }

    console.log('\n✅ Passwords removed from Firestore!\n');
}

removePasswords();