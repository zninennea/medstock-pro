// admin_tool/seed_demo_data.js
const admin = require('firebase-admin');

const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function seedDemoData() {
    console.log('\n=== Seeding Complete Demo Data ===\n');

    const now = new Date();
    const currentPeriod = new Date(now.getFullYear(), now.getMonth(), 1);

    const tenants = [{
            id: 'davmedical',
            name: 'Davao Medical Center',
            address: 'Davao City, Davao del Sur',
            tier: 'Basic',
            billing: 4500,
            email: 'admin@davmedical.com',
            suspended: false
        },
        {
            id: 'cebgeneral',
            name: 'Cebu General Hospital',
            address: 'Cebu City, Cebu',
            tier: 'Premium',
            billing: 12500,
            email: 'admin@cebgeneral.com',
            suspended: false
        }
    ];

    for (const tenant of tenants) {
        console.log(`\n📁 Processing tenant: ${tenant.name} (${tenant.id})`);

        // 1. Create/Update Tenant Document
        const tenantRef = db.collection('tenants').doc(tenant.id);
        await tenantRef.set({
            name: tenant.name,
            address: tenant.address,
            tier: tenant.tier,
            billing: tenant.billing,
            email: tenant.email,
            suspended: tenant.suspended
        });
        console.log('  ✅ Tenant document created');

        // 2. Add Staff Members
        const staffMembers = [
            { email: 'maria.santos@davmedical.com', name: 'Maria Santos', role: 'staff', createdBy: 'admin@davmedical.com' },
            { email: 'jun.reyes@davmedical.com', name: 'Jun Reyes', role: 'staff', createdBy: 'admin@davmedical.com' }
        ];

        for (const staff of staffMembers) {
            if (staff.email.includes(tenant.id)) {
                await tenantRef.collection('staff').doc(staff.email).set({
                    email: staff.email,
                    name: staff.name,
                    role: staff.role,
                    tenantId: tenant.id,
                    createdBy: staff.createdBy
                });
                console.log(`  ✅ Staff added: ${staff.name} (${staff.email})`);
            }
        }

        // 3. Add Products
        const products = [{
                meds: 'Amoxicillin',
                brand: 'Medcor',
                category: 'Antibiotics',
                lotNumber: 'LOT-001',
                qty: 85,
                uom: 'Piece',
                cost: 45.0,
                srp: 85.0,
                expirationDate: new Date(now.getFullYear() + 1, now.getMonth(), now.getDate()),
                reorderThreshold: 30,
                supplier: 'Medcor Pharma'
            },
            {
                meds: 'Paracetamol',
                brand: 'RiteMed',
                category: 'Pain Relief',
                lotNumber: 'LOT-002',
                qty: 12,
                uom: 'Piece',
                cost: 32.0,
                srp: 65.0,
                expirationDate: new Date(now.getFullYear(), now.getMonth() + 1, now.getDate()),
                reorderThreshold: 30,
                supplier: 'RiteMed Corp'
            },
            {
                meds: 'Ibuprofen',
                brand: 'Advil',
                category: 'Pain Relief',
                lotNumber: 'LOT-003',
                qty: 45,
                uom: 'Piece',
                cost: 28.0,
                srp: 55.0,
                expirationDate: new Date(now.getFullYear() + 2, now.getMonth(), now.getDate()),
                reorderThreshold: 20,
                supplier: 'Pfizer'
            },
            {
                meds: 'Vitamin C',
                brand: 'Ascorbic',
                category: 'Vitamins',
                lotNumber: 'LOT-004',
                qty: 89,
                uom: 'Piece',
                cost: 15.0,
                srp: 35.0,
                expirationDate: new Date(now.getFullYear() + 1, now.getMonth() + 3, now.getDate()),
                reorderThreshold: 50,
                supplier: "Nature's Way"
            }
        ];

        for (const product of products) {
            const productId = `${tenant.id}_${product.lotNumber.toLowerCase()}_${Date.now()}_${Math.random()}`;
            await tenantRef.collection('products').doc(productId).set({
                ...product,
                tenantId: tenant.id,
                expirationDate: admin.firestore.Timestamp.fromDate(product.expirationDate),
                createdAt: admin.firestore.Timestamp.fromDate(now),
                updatedAt: admin.firestore.Timestamp.fromDate(now)
            });
            console.log(`  ✅ Product added: ${product.meds}`);
        }

        // 4. Add Initial Payment
        const paymentRef = await db.collection('payments').add({
            tenantId: tenant.id,
            tenantName: tenant.name,
            date: admin.firestore.Timestamp.fromDate(now),
            amount: tenant.billing,
            receiptUrl: '',
            receiptData: null,
            method: 'Cash',
            period: admin.firestore.Timestamp.fromDate(currentPeriod),
            reference: `INITIAL-${tenant.id}-${Date.now()}`,
            isVerified: true,
            timestamp: admin.firestore.Timestamp.fromDate(now),
            recordedBy: 'System (Demo Data)',
            note: 'Initial payment for demo tenant'
        });
        console.log(`  ✅ Payment recorded: ₱${tenant.billing}`);

        // 5. Add Sample Transactions
        const transactions = [{
                productName: 'Amoxicillin',
                lotNumber: 'LOT-001',
                type: 'in',
                qty: 50,
                reason: 'Restock (Purchase)',
                reference: `TX-IN-${Date.now()}`,
                staffName: 'Maria Santos',
                balAfter: 85
            },
            {
                productName: 'Paracetamol',
                lotNumber: 'LOT-002',
                type: 'out',
                qty: 10,
                reason: 'Dispensed to Patient',
                reference: `TX-OUT-${Date.now()}`,
                staffName: 'Maria Santos',
                balAfter: 12
            }
        ];

        for (const trans of transactions) {
            await tenantRef.collection('transactions').add({
                ...trans,
                tenantId: tenant.id,
                productId: `${tenant.id}_${trans.lotNumber.toLowerCase()}`,
                timestamp: admin.firestore.Timestamp.fromDate(now),
                staffId: 'staff1'
            });
            console.log(`  ✅ Transaction added: ${trans.type} - ${trans.productName}`);
        }

        // 6. Add Audit Entries
        const auditEntries = [{
                action: 'Tenant Created',
                details: `Tenant ${tenant.name} was created`,
                user: 'Super Admin',
                role: 'superAdmin'
            },
            {
                action: 'Payment Recorded',
                details: `Initial payment of ₱${tenant.billing} recorded`,
                user: 'System',
                role: 'system'
            },
            {
                action: 'Products Added',
                details: 'Initial product inventory loaded',
                user: 'System',
                role: 'system'
            }
        ];

        for (const audit of auditEntries) {
            await tenantRef.collection('audit').add({
                ...audit,
                timestamp: admin.firestore.Timestamp.fromDate(now)
            });
        }
        console.log('  ✅ Audit entries added');
    }

    // 7. Add Super Admin Audit Entry
    await db.collection('superAdminAudit').add({
        action: 'Demo Data Seeded',
        details: 'Complete demo data seeded for all tenants',
        timestamp: admin.firestore.Timestamp.fromDate(now),
        recordedBy: 'System'
    });
    console.log('\n✅ Super Admin audit entry added');

    console.log('\n========================================');
    console.log('✅ Demo Data Seeding Complete!');
    console.log('========================================');
    console.log('\nSeeded data includes:');
    console.log('  • 2 Tenants (Davao Medical, Cebu General)');
    console.log('  • 2 Staff members per tenant');
    console.log('  • 4 Products per tenant');
    console.log('  • Initial payment records');
    console.log('  • Sample transactions');
    console.log('  • Audit trail entries');
    console.log('========================================\n');
}

seedDemoData();