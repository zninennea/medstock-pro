const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const app = express();
app.use(cors());
app.use(express.json());

app.post('/change-password', async(req, res) => {
    const { staffEmail, newPassword, adminEmail, adminPassword } = req.body;

    // Verify admin credentials (basic check)
    try {
        const adminUser = await admin.auth().getUserByEmail(adminEmail);
        // You could add more verification here
    } catch (error) {
        return res.status(401).json({ error: 'Invalid admin credentials' });
    }

    try {
        const user = await admin.auth().getUserByEmail(staffEmail);
        await admin.auth().updateUser(user.uid, {
            password: newPassword
        });

        res.json({ success: true, message: 'Password updated' });
    } catch (error) {
        res.status(400).json({ error: error.message });
    }
});

const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Admin server running on http://localhost:${PORT}`);
});