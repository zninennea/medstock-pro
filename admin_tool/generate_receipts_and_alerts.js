const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Helper function to generate receipt ID
function generateReceiptId(tenantId, paymentId) {
    return tenantId + '_' + paymentId + '_' + Date.now();
}

// Helper function to generate alert ID
function generateAlertId(tenantId, type) {
    return tenantId + '_' + type + '_' + Date.now();
}

// Function to generate receipt from payment record
async function generateReceiptFromPayment(paymentDoc, tenantId, tenantName) {
    const data = paymentDoc.data();
    const paymentId = paymentDoc.id;
    const receiptId = generateReceiptId(tenantId, paymentId);

    // Check if receipt already exists
    const existingReceipt = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('receipts')
        .doc(receiptId)
        .get();

    if (existingReceipt.exists) {
        console.log('   ⏭️ Receipt already exists for payment:', paymentId);
        return;
    }

    // Create receipt from payment data
    const receiptData = {
        receiptId: receiptId,
        paymentId: paymentId,
        tenantId: tenantId,
        tenantName: tenantName,
        amount: data.amount,
        method: data.method,
        reference: data.reference,
        paymentDate: data.date,
        period: data.period,
        receiptUrl: data.receiptUrl || '',
        receiptData: data.receiptData || null,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        generatedBy: 'system',
        verified: data.isVerified || false,
    };

    await db
        .collection('tenants')
        .doc(tenantId)
        .collection('receipts')
        .doc(receiptId)
        .set(receiptData);

    console.log('   ✅ Generated receipt:', receiptId, 'for amount ₱' + data.amount);
}

// Function to generate alerts from low stock products
async function generateLowStockAlerts(tenantId, tenantName, products) {
    let alertCount = 0;

    for (const product of products) {
        const productData = product.data();
        const productId = product.id;
        const currentStock = productData.qty || 0;
        const reorderThreshold = productData.reorderThreshold || 10;

        // Check if low stock
        if (currentStock <= reorderThreshold) {
            const alertId = generateAlertId(tenantId, 'low_stock_' + productId);

            // Check if alert already exists
            const existingAlert = await db
                .collection('tenants')
                .doc(tenantId)
                .collection('alerts')
                .doc(alertId)
                .get();

            if (!existingAlert.exists) {
                const severity = currentStock === 0 ? 'critical' : 'warning';
                const productName = productData.meds || 'Product';
                const lotNumber = productData.lotNumber || 'N/A';

                const alertData = {
                    alertId: alertId,
                    tenantId: tenantId,
                    tenantName: tenantName,
                    type: 'low_stock',
                    severity: severity,
                    message: '⚠️ Low stock alert: ' + productName + ' (Lot: ' + lotNumber + ') has only ' + currentStock + ' units left (threshold: ' + reorderThreshold + ')',
                    productId: productId,
                    productName: productName,
                    currentStock: currentStock,
                    threshold: reorderThreshold,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    read: false,
                    readBy: [],
                    actionRequired: true,
                };

                await db
                    .collection('tenants')
                    .doc(tenantId)
                    .collection('alerts')
                    .doc(alertId)
                    .set(alertData);

                alertCount++;
                console.log('   ✅ Generated low stock alert for:', productName, '(Stock:', currentStock + ')');
            }
        }
    }

    return alertCount;
}

// Function to generate alerts from expiring products
async function generateExpiryAlerts(tenantId, tenantName, products) {
    let alertCount = 0;
    const now = new Date();
    const ninetyDaysFromNow = new Date();
    ninetyDaysFromNow.setDate(now.getDate() + 90);

    for (const product of products) {
        const productData = product.data();
        const productId = product.id;
        const expiryDate = productData.expirationDate ? productData.expirationDate.toDate() : null;

        if (!expiryDate) continue;

        const daysUntilExpiry = Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24));

        // Check if expiring within 90 days
        if (daysUntilExpiry <= 90 && daysUntilExpiry > 0) {
            const alertId = generateAlertId(tenantId, 'expiry_' + productId);

            // Check if alert already exists
            const existingAlert = await db
                .collection('tenants')
                .doc(tenantId)
                .collection('alerts')
                .doc(alertId)
                .get();

            if (!existingAlert.exists) {
                let severity = 'info';
                if (daysUntilExpiry <= 7) severity = 'critical';
                else if (daysUntilExpiry <= 30) severity = 'warning';

                const productName = productData.meds || 'Product';
                const lotNumber = productData.lotNumber || 'N/A';
                const expiryDateStr = expiryDate.toISOString().split('T')[0];

                const alertData = {
                    alertId: alertId,
                    tenantId: tenantId,
                    tenantName: tenantName,
                    type: 'expiring',
                    severity: severity,
                    message: '📅 Expiry alert: ' + productName + ' (Lot: ' + lotNumber + ') expires in ' + daysUntilExpiry + ' days on ' + expiryDateStr,
                    productId: productId,
                    productName: productName,
                    lotNumber: lotNumber,
                    expiryDate: expiryDate,
                    daysUntilExpiry: daysUntilExpiry,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    read: false,
                    readBy: [],
                    actionRequired: daysUntilExpiry <= 7,
                };

                await db
                    .collection('tenants')
                    .doc(tenantId)
                    .collection('alerts')
                    .doc(alertId)
                    .set(alertData);

                alertCount++;
                console.log('   ✅ Generated expiry alert for:', productName, '(Expires in', daysUntilExpiry, 'days)');
            }
        }
    }

    return alertCount;
}

// Function to generate payment due alerts
async function generatePaymentDueAlerts(tenantId, tenantName, lastPaymentDate, billingAmount) {
    if (!lastPaymentDate) return 0;

    const now = new Date();
    const nextPaymentDate = new Date(lastPaymentDate);
    nextPaymentDate.setMonth(nextPaymentDate.getMonth() + 1);

    const daysUntilDue = Math.ceil((nextPaymentDate - now) / (1000 * 60 * 60 * 24));
    const daysOverdue = daysUntilDue < 0 ? Math.abs(daysUntilDue) : 0;

    // Generate alert if payment is due within 7 days or overdue
    if (daysUntilDue <= 7 || daysOverdue > 0) {
        const alertId = generateAlertId(tenantId, 'payment_due');

        // Check if alert already exists
        const existingAlert = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('alerts')
            .doc(alertId)
            .get();

        if (!existingAlert.exists) {
            let message = '';
            const severity = daysOverdue > 0 ? 'critical' : 'warning';

            if (daysOverdue > 0) {
                message = '💰 Payment overdue: ₱' + billingAmount.toFixed(2) + ' is ' + daysOverdue + ' days overdue';
            } else {
                message = '💰 Payment due soon: ₱' + billingAmount.toFixed(2) + ' is due in ' + daysUntilDue + ' days';
            }

            const alertData = {
                alertId: alertId,
                tenantId: tenantId,
                tenantName: tenantName,
                type: 'payment_due',
                severity: severity,
                message: message,
                amount: billingAmount,
                dueDate: nextPaymentDate,
                daysUntilDue: daysUntilDue,
                daysOverdue: daysOverdue,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                read: false,
                readBy: [],
                actionRequired: true,
            };

            await db
                .collection('tenants')
                .doc(tenantId)
                .collection('alerts')
                .doc(alertId)
                .set(alertData);

            console.log('   ✅ Generated payment due alert for:', tenantName);
            return 1;
        }
    }

    return 0;
}

// Main function to process all tenants
async function generateReceiptsAndAlerts() {
    console.log('\n========================================');
    console.log('📋 GENERATING RECEIPTS AND ALERTS');
    console.log('========================================\n');

    // Get all tenants
    const tenantsSnapshot = await db.collection('tenants').get();
    console.log('Found', tenantsSnapshot.size, 'tenants\n');

    let totalReceipts = 0;
    let totalLowStockAlerts = 0;
    let totalExpiryAlerts = 0;
    let totalPaymentAlerts = 0;

    for (const tenantDoc of tenantsSnapshot.docs) {
        const tenantId = tenantDoc.id;
        const tenantData = tenantDoc.data();
        const tenantName = tenantData.name || tenantId;

        console.log('\n📁 Processing tenant:', tenantName, '(' + tenantId + ')');
        console.log('─'.repeat(50));

        // 1. Generate receipts from payments
        console.log('\n💰 Generating receipts from payments...');
        const paymentsSnapshot = await db
            .collection('payments')
            .where('tenantId', '==', tenantId)
            .get();

        let receiptsCount = 0;
        for (const paymentDoc of paymentsSnapshot.docs) {
            await generateReceiptFromPayment(paymentDoc, tenantId, tenantName);
            receiptsCount++;
        }
        totalReceipts += receiptsCount;
        console.log('   📊 Processed', receiptsCount, 'payments');

        // 2. Generate low stock alerts from products
        console.log('\n📦 Generating low stock alerts...');
        const productsSnapshot = await db
            .collection('tenants')
            .doc(tenantId)
            .collection('products')
            .get();

        const lowStockCount = await generateLowStockAlerts(tenantId, tenantName, productsSnapshot.docs);
        totalLowStockAlerts += lowStockCount;
        console.log('   📊 Generated', lowStockCount, 'low stock alerts');

        // 3. Generate expiry alerts from products
        console.log('\n📅 Generating expiry alerts...');
        const expiryCount = await generateExpiryAlerts(tenantId, tenantName, productsSnapshot.docs);
        totalExpiryAlerts += expiryCount;
        console.log('   📊 Generated', expiryCount, 'expiry alerts');

        // 4. Generate payment due alerts
        console.log('\n💰 Generating payment due alerts...');
        const lastPaymentSnapshot = await db
            .collection('payments')
            .where('tenantId', '==', tenantId)
            .orderBy('timestamp', 'desc')
            .limit(1)
            .get();

        let paymentAlertCount = 0;
        if (!lastPaymentSnapshot.empty) {
            const lastPayment = lastPaymentSnapshot.docs[0].data();
            const lastPaymentDate = lastPayment.timestamp ? lastPayment.timestamp.toDate() : null;
            const billingAmount = tenantData.billing || 0;

            paymentAlertCount = await generatePaymentDueAlerts(tenantId, tenantName, lastPaymentDate, billingAmount);
        }
        totalPaymentAlerts += paymentAlertCount;
        console.log('   📊 Generated', paymentAlertCount, 'payment due alerts');
    }

    // Summary
    console.log('\n========================================');
    console.log('✅ GENERATION COMPLETE');
    console.log('========================================');
    console.log('📊 Total receipts generated:', totalReceipts);
    console.log('📊 Total low stock alerts:', totalLowStockAlerts);
    console.log('📊 Total expiry alerts:', totalExpiryAlerts);
    console.log('📊 Total payment due alerts:', totalPaymentAlerts);
    console.log('========================================\n');
}

// Function to save receipt to Super Admin collection
async function saveReceiptToSuperAdmin(tenantId, tenantName, paymentData, receiptId) {
    const superAdminRef = db.collection('superAdmin').doc('superadmin');

    // Check if super admin document exists, create if not
    const superAdminDoc = await superAdminRef.get();
    if (!superAdminDoc.exists) {
        await superAdminRef.set({
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: 'system'
        });
    }

    await superAdminRef
        .collection('receipts')
        .doc(receiptId)
        .set({
            receiptId: receiptId,
            tenantId: tenantId,
            tenantName: tenantName,
            amount: paymentData.amount,
            method: paymentData.method,
            reference: paymentData.reference,
            receiptData: paymentData.receiptData || '',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            uploadedBy: 'system',
            verified: paymentData.isVerified || false,
            verifiedAt: paymentData.isVerified ? admin.firestore.FieldValue.serverTimestamp() : null,
            verifiedBy: paymentData.isVerified ? 'system' : null,
        });

    console.log('   ✅ Saved receipt to Super Admin collection');
}

// Run the main function
generateReceiptsAndAlerts()
    .then(function() {
        console.log('Script completed successfully!');
        process.exit(0);
    })
    .catch(function(error) {
        console.error('Error:', error);
        process.exit(1);
    });