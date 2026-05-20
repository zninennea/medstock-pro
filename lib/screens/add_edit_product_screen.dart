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
    'Pain Relief',
    'Vitamins',
    'Cardiovascular',
    'Diabetes',
    'Respiratory'
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
    _category = product?.category ?? _categories.first;
    _uom = product?.uom ?? _uomOptions.first;
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
                initialValue: _category,
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
                      initialValue: _uom,
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
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _srpController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration('SRP (₱)'),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
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

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);

    final product = Product(
      id: widget.product?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      tenantId: authProvider.currentTenantId!,
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
