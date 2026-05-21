const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function recoverMissingTenants() {
    console.log('\n========================================');
    console.log('🔍 RECOVERING MISSING TENANTS');
    console.log('========================================\n');

    // 1. Get all tenants from Firestore
    const tenantsSnapshot = await db.collection('tenants').get();

    console.log(`📊 Found ${tenantsSnapshot.size} tenants in Firestore:\n`);

    const tenants = [];
    for (const doc of tenantsSnapshot.docs) {
        const data = doc.data();
        tenants.push({
            id: doc.id,
            name: data.name || doc.id,
            email: data.email || 'No email',
            address: data.address || 'No address',
            tier: data.tier || 'Basic',
            billing: data.billing || 0,
            paid: data.paid || false,
            suspended: data.suspended || false,
        });
    }

    // Display all tenants
    tenants.forEach((tenant, index) => {
        console.log(`${index + 1}. ${tenant.name} (${tenant.id})`);
        console.log(`   Email: ${tenant.email}`);
        console.log(`   Status: ${tenant.suspended ? 'SUSPENDED' : (tenant.paid ? 'PAID' : 'UNPAID')}`);
        console.log(`   Plan: ${tenant.tier} - ₱${tenant.billing}/month`);
        console.log('');
    });

    // 2. Check which tenants have products
    console.log('📦 Checking products for each tenant...\n');

    for (const tenant of tenants) {
        const productsSnapshot = await db
            .collection('tenants')
            .doc(tenant.id)
            .collection('products')
            .get();

        console.log(`${tenant.name}: ${productsSnapshot.size} products`);
    }

    // 3. Check which tenants have staff
    console.log('\n👥 Checking staff for each tenant...\n');

    for (const tenant of tenants) {
        const staffSnapshot = await db
            .collection('tenants')
            .doc(tenant.id)
            .collection('staff')
            .get();

        console.log(`${tenant.name}: ${staffSnapshot.size} staff members`);
    }

    // 4. Check which tenants have payment records
    console.log('\n💰 Checking payment records for each tenant...\n');

    for (const tenant of tenants) {
        const paymentsSnapshot = await db
            .collection('payments')
            .where('tenantId', '==', tenant.id)
            .get();

        console.log(`${tenant.name}: ${paymentsSnapshot.size} payment records`);
    }

    console.log('\n========================================');
    console.log('✅ RECOVERY CHECK COMPLETE');
    console.log('========================================\n');

    return tenants;
}

// Function to fix tenant display issues
async function fixTenantDisplay() {
    console.log('\n🛠️ FIXING TENANT DISPLAY ISSUES\n');

    const tenantsSnapshot = await db.collection('tenants').get();

    for (const doc of tenantsSnapshot.docs) {
        const data = doc.data();
        const tenantId = doc.id;

        // Ensure required fields exist
        const updates = {};
        let needsUpdate = false;

        if (!data.name) {
            updates.name = tenantId.charAt(0).toUpperCase() + tenantId.slice(1);
            needsUpdate = true;
        }
        if (data.paid === undefined) {
            updates.paid = false;
            needsUpdate = true;
        }
        if (data.suspended === undefined) {
            updates.suspended = false;
            needsUpdate = true;
        }
        if (!data.tier) {
            updates.tier = 'Basic';
            needsUpdate = true;
        }
        if (!data.billing) {
            updates.billing = data.tier === 'Premium' ? 12500 : 4500;
            needsUpdate = true;
        }

        if (needsUpdate) {
            await db.collection('tenants').doc(tenantId).update(updates);
            console.log(`✅ Fixed tenant data for: ${tenantId}`);
            console.log(`   Updated: ${JSON.stringify(updates)}`);
        } else {
            console.log(`✅ Tenant OK: ${tenantId}`);
        }
    }

    console.log('\n✅ Tenant display fix complete!\n');
}

// Function to restore a specific tenant (if needed)
async function restoreTenant(tenantId, tenantData) {
    console.log(`\n🔄 Restoring tenant: ${tenantId}\n`);

    // Check if tenant already exists
    const tenantDoc = await db.collection('tenants').doc(tenantId).get();

    if (tenantDoc.exists) {
        console.log(`⚠️ Tenant ${tenantId} already exists. Updating...`);
        await db.collection('tenants').doc(tenantId).update(tenantData);
    } else {
        console.log(`📝 Creating tenant: ${tenantId}`);
        await db.collection('tenants').doc(tenantId).set(tenantData);
    }

    // Ensure products subcollection exists (create empty if needed)
    const productsCheck = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('products')
        .limit(1)
        .get();

    if (productsCheck.empty) {
        console.log(`📦 No products found for ${tenantId}. You can add products through the UI.`);
    }

    console.log(`✅ Tenant ${tenantId} restored successfully!`);
}

// Run the recovery
async function main() {
    const tenants = await recoverMissingTenants();
    await fixTenantDisplay();

    console.log('\n📋 INSTRUCTIONS:');
    console.log('1. Restart your Flutter app');
    console.log('2. Login as Super Admin');
    console.log('3. Click "Refresh" in Tenant Management');
    console.log('4. All tenants should now appear');

    // If you want to restore a specific tenant that was deleted from UI but exists in DB
    // Uncomment and modify below:
    /*
    const missingTenantId = 'med_cares'; // Replace with your tenant ID
    const missingTenantData = {
      name: 'Med Cares',
      address: 'Your Address Here',
      tier: 'Basic',
      billing: 4500,
      email: 'admin@medcares.com',
      paid: false,
      suspended: false,
    };
    await restoreTenant(missingTenantId, missingTenantData);
    */

    process.exit(0);
}

main();