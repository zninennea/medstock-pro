// lib/screens/add_edit_product_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/tenant_provider.dart';
import '../providers/product_provider.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _medsController;
  late TextEditingController _brandController;
  late TextEditingController _lotController;
  late TextEditingController _qtyController;
  late TextEditingController _costController;
  late TextEditingController _srpController;
  late TextEditingController _reorderController;
  late TextEditingController _supplierController;
  late DateTime _expiryDate;
  late String _category;
  late String _uom;

  final List<String> _categories = [
    'Antibiotics',
    'Analgesics (Pain Relief)',
    'Vitamins & Supplements',
    'Cardiovascular',
    'Antidiabetics',
    'Respiratory',
    'Gastrointestinal',
    'Topical Creams & Ointments',
    'Medical Supplies',
    'Antihistamines',
    'Antihypertensives',
    'Antifungals',
    'Antivirals',
    'Ophthalmics (Eye Care)',
    'First Aid',
    'Others'
  ];

  final List<String> _uomOptions = ['Strip', 'Piece', 'Box', 'Bottle', 'Tube'];

  @override
  void initState() {
    super.initState();
    final product = widget.product;

    _medsController = TextEditingController(text: product?.meds ?? '');
    _brandController = TextEditingController(text: product?.brand ?? '');
    _lotController = TextEditingController(text: product?.lotNumber ?? '');
    _qtyController =
        TextEditingController(text: (product?.qty ?? 0).toString());
    _costController =
        TextEditingController(text: (product?.cost ?? 0).toString());
    _srpController =
        TextEditingController(text: (product?.srp ?? 0).toString());
    _reorderController = TextEditingController(
        text: (product?.reorderThreshold ?? 10).toString());
    _supplierController = TextEditingController(text: product?.supplier ?? '');
    _expiryDate = product?.expirationDate ??
        DateTime.now().add(const Duration(days: 365));

    // Check if the product's category exists in the list
    if (product?.category != null && _categories.contains(product!.category)) {
      _category = product.category;
    } else {
      _category = _categories.first;
    }

    // Check if UOM exists in list
    if (product?.uom != null && _uomOptions.contains(product!.uom)) {
      _uom = product.uom;
    } else {
      _uom = _uomOptions.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _medsController,
                decoration: _buildInputDecoration('Product Name'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandController,
                decoration: _buildInputDecoration('Brand'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: _buildInputDecoration('Category'),
                items: _categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _category = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lotController,
                decoration: _buildInputDecoration('Lot Number'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('Quantity'),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _uom,
                      decoration: _buildInputDecoration('UOM'),
                      items: _uomOptions
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(u),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _uom = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('Cost (₱)'),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Required';
                        if (double.tryParse(v!) == null)
                          return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _srpController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('SRP (₱)'),
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Required';
                        if (double.tryParse(v!) == null)
                          return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _reorderController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('Reorder Threshold'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _expiryDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (date != null) {
                          setState(() {
                            _expiryDate = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: _buildInputDecoration('Expiry Date'),
                        child: Text(_formatDate(_expiryDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _supplierController,
                decoration: _buildInputDecoration('Supplier'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isEditing ? 'Update Product' : 'Save Product',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final tenantId = authProvider.currentTenantId!;

    // CHECK FOR DUPLICATE LOT NUMBER
    Product? existingProduct;
    for (final product in productProvider.products) {
      if (product.lotNumber.toLowerCase() ==
          _lotController.text.toLowerCase().trim()) {
        existingProduct = product;
        break;
      }
    }

    // If editing the same product, skip duplicate check
    final isEditingSameProduct = widget.product != null &&
        widget.product!.lotNumber.toLowerCase() ==
            _lotController.text.toLowerCase().trim();

    if (existingProduct != null && !isEditingSameProduct) {
      _showDuplicateProductDialog(existingProduct);
      return;
    }

    // Create product
    final product = Product(
      id: widget.product?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      tenantId: tenantId,
      meds: _medsController.text,
      brand: _brandController.text,
      category: _category,
      lotNumber: _lotController.text,
      qty: int.parse(_qtyController.text),
      uom: _uom,
      cost: double.parse(_costController.text),
      srp: double.parse(_srpController.text),
      expirationDate: _expiryDate,
      reorderThreshold: int.parse(_reorderController.text),
      supplier: _supplierController.text,
    );

    final tenantProvider = Provider.of<TenantProvider>(context, listen: false);

    try {
      if (widget.product == null) {
        await productProvider.addProduct(product);
        tenantProvider.addProduct(authProvider.currentTenantId!, product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Product added successfully!')),
          );
        }
      } else {
        await productProvider.updateProduct(product);
        tenantProvider.updateProduct(authProvider.currentTenantId!, product);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Product updated successfully!')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updateExistingProductStock(Product existingProduct) async {
    final newQty = existingProduct.qty + int.parse(_qtyController.text);
    final updatedProduct = existingProduct.copyWith(qty: newQty);

    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await productProvider.updateProduct(updatedProduct);
      tenantProvider.updateProduct(
          authProvider.currentTenantId!, updatedProduct);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Added ${_qtyController.text} units to existing product. New stock: $newQty'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDuplicateProductDialog(Product existingProduct) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Product Already Exists'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A product with lot number "${_lotController.text}" already exists.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Product:', existingProduct.meds),
                  _buildDetailRow('Brand:', existingProduct.brand),
                  _buildDetailRow('Current Stock:',
                      '${existingProduct.qty} ${existingProduct.uom}'),
                  _buildDetailRow('Expiry Date:',
                      _formatDate(existingProduct.expirationDate)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'What would you like to do?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _updateExistingProductStock(existingProduct);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add to Existing Stock'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _saveNewProductForce();
            },
            icon: const Icon(Icons.create_new_folder, size: 18),
            label: const Text('Create New Anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNewProductForce() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final tenantId = authProvider.currentTenantId!;

    final product = Product(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tenantId: tenantId,
      meds: _medsController.text,
      brand: _brandController.text,
      category: _category,
      lotNumber: _lotController.text,
      qty: int.parse(_qtyController.text),
      uom: _uom,
      cost: double.parse(_costController.text),
      srp: double.parse(_srpController.text),
      expirationDate: _expiryDate,
      reorderThreshold: int.parse(_reorderController.text),
      supplier: _supplierController.text,
    );

    final tenantProvider = Provider.of<TenantProvider>(context, listen: false);

    try {
      await productProvider.addProduct(product);
      tenantProvider.addProduct(authProvider.currentTenantId!, product);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Product created successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Error: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _medsController.dispose();
    _brandController.dispose();
    _lotController.dispose();
    _qtyController.dispose();
    _costController.dispose();
    _srpController.dispose();
    _reorderController.dispose();
    _supplierController.dispose();
    super.dispose();
  }
}
