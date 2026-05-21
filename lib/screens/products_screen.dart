// lib/screens/products_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/product_provider.dart';
import '../providers/tenant_provider.dart';
import '../models/product.dart';
import 'add_edit_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = '';
  String _selectedSort = 'az';
  List<String> _availableCategories = []; // Categories from actual products

  // Pagination variables
  int _currentPage = 0;
  int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  Future<void> _loadProducts() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
    if (authProvider.currentTenantId != null) {
      await productProvider.loadProducts(authProvider.currentTenantId!);
      tenantProvider.syncProducts(
          authProvider.currentTenantId!, productProvider.products);
      _updateCategories();
    }
  }

  void _updateCategories() {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    // Get unique categories from actual products only
    final categories = productProvider.products
        .map((p) => p.category)
        .where((cat) => cat.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    setState(() {
      _availableCategories = categories;
    });
    print('Available categories from products: $_availableCategories');
  }

  List<Product> _getFilteredProducts(List<Product> allProducts) {
    var filtered = List<Product>.from(allProducts);

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where((p) =>
              p.meds.toLowerCase().contains(query) ||
              p.brand.toLowerCase().contains(query) ||
              p.lotNumber.toLowerCase().contains(query))
          .toList();
    }

    // Category filter - ONLY filter if a valid category is selected
    if (_selectedCategory.isNotEmpty &&
        _selectedCategory != 'All Categories' &&
        _availableCategories.contains(_selectedCategory)) {
      filtered =
          filtered.where((p) => p.category == _selectedCategory).toList();
      print(
          'Filtering by category: $_selectedCategory, found ${filtered.length} products');
    }

    // Sort
    switch (_selectedSort) {
      case 'az':
        filtered.sort((a, b) => a.meds.compareTo(b.meds));
        break;
      case 'za':
        filtered.sort((a, b) => b.meds.compareTo(a.meds));
        break;
      case 'qty-low':
        filtered.sort((a, b) => a.qty.compareTo(b.qty));
        break;
      case 'qty-high':
        filtered.sort((a, b) => b.qty.compareTo(a.qty));
        break;
      case 'expiry':
        filtered.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final isAdmin = authProvider.isAdmin;
    final allProducts = productProvider.products;

    if (productProvider.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading products...'),
          ],
        ),
      );
    }

    // Apply filters
    final filteredProducts = _getFilteredProducts(allProducts);

    // Paginate
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage) > filteredProducts.length
        ? filteredProducts.length
        : startIndex + _itemsPerPage;
    final pageProducts = filteredProducts.sublist(startIndex, endIndex);
    final totalPages = filteredProducts.isEmpty
        ? 1
        : (filteredProducts.length / _itemsPerPage).ceil();

    return Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, lot, or brand...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _currentPage = 0;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {
                  _currentPage = 0;
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value:
                          _selectedCategory.isEmpty ? null : _selectedCategory,
                      hint: const Text('All Categories'),
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: '', child: Text('All Categories')),
                        ..._availableCategories.map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (value) {
                        print('Dropdown changed to: $value');
                        setState(() {
                          _selectedCategory = value ?? '';
                          _currentPage = 0;
                        });
                        print('New selected category: $_selectedCategory');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSort,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'az', child: Text('Name A → Z')),
                        DropdownMenuItem(
                            value: 'za', child: Text('Name Z → A')),
                        DropdownMenuItem(
                            value: 'qty-low',
                            child: Text('Stock (Low to High)')),
                        DropdownMenuItem(
                            value: 'qty-high',
                            child: Text('Stock (High to Low)')),
                        DropdownMenuItem(
                            value: 'expiry', child: Text('Expiry (Soonest)')),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedSort = value!);
                      },
                    ),
                  ),
                ],
              ),
              if (_availableCategories.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No categories available. Add products with categories first.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
            ],
          ),
        ),

        // Add Product Button (Admin only)
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AddEditProductScreen()),
                  );
                  if (result == true) {
                    _loadProducts();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Products Table
        Expanded(
          child: filteredProducts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No products found'),
                      SizedBox(height: 8),
                      Text('Try adjusting your search or filter criteria'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Horizontal and Vertical scroll table
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columnSpacing: 16,
                            headingRowHeight: 56,
                            dataRowMinHeight: 56,
                            dataRowMaxHeight: 80,
                            columns: [
                              const DataColumn(
                                  label: Text('Meds',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('Brand',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('Category',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('Lot#',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('Qty',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('UOM',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('SRP',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('Expiry Date',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              const DataColumn(
                                  label: Text('Status',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold))),
                              if (isAdmin)
                                const DataColumn(
                                    label: Text('Actions',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                            ],
                            rows: pageProducts.map((product) {
                              final daysUntilExpiry = product.expirationDate
                                  .difference(DateTime.now())
                                  .inDays;
                              return DataRow(
                                cells: [
                                  DataCell(SizedBox(
                                    width: 150,
                                    child: Text(
                                      product.meds,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                                  DataCell(SizedBox(
                                    width: 120,
                                    child: Text(product.brand,
                                        overflow: TextOverflow.ellipsis),
                                  )),
                                  DataCell(SizedBox(
                                    width: 120,
                                    child: Text(product.category,
                                        overflow: TextOverflow.ellipsis),
                                  )),
                                  DataCell(Text(
                                    product.lotNumber,
                                    style: const TextStyle(
                                        fontFamily: 'monospace', fontSize: 11),
                                  )),
                                  DataCell(Text('${product.qty}')),
                                  DataCell(Text(product.uom)),
                                  DataCell(Text(
                                      '₱${product.srp.toStringAsFixed(2)}')),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatDate(product.expirationDate),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: daysUntilExpiry <= 30
                                                ? (daysUntilExpiry <= 7
                                                    ? Colors.red
                                                    : Colors.orange)
                                                : null,
                                            fontWeight: daysUntilExpiry <= 30
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (daysUntilExpiry <= 30 &&
                                            daysUntilExpiry > 0)
                                          const SizedBox(width: 4),
                                        if (daysUntilExpiry <= 30 &&
                                            daysUntilExpiry > 0)
                                          Icon(
                                            Icons.warning,
                                            size: 14,
                                            color: daysUntilExpiry <= 7
                                                ? Colors.red
                                                : Colors.orange,
                                          ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(product)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusText(product),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _getStatusColor(product),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isAdmin)
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 18),
                                            onPressed: () async {
                                              final result =
                                                  await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      AddEditProductScreen(
                                                          product: product),
                                                ),
                                              );
                                              if (result == true) {
                                                _loadProducts();
                                              }
                                            },
                                            color: Colors.blue,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                size: 18),
                                            onPressed: () =>
                                                _showDeleteDialog(product),
                                            color: Colors.red,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Pagination controls
                    _buildPaginationControls(
                      currentPage: _currentPage,
                      totalPages: totalPages,
                      totalItems: filteredProducts.length,
                      itemsPerPage: _itemsPerPage,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      onItemsPerPageChanged: (value) {
                        setState(() {
                          _itemsPerPage = value;
                          _currentPage = 0;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int itemsPerPage,
    required Function(int) onPageChanged,
    required Function(int) onItemsPerPageChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Show: ', style: TextStyle(fontSize: 12)),
              DropdownButton<int>(
                value: itemsPerPage,
                items: const [5, 10, 25, 50].map((value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value', style: TextStyle(fontSize: 12)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onItemsPerPageChanged(value);
                  }
                },
              ),
              const SizedBox(width: 16),
              Text(
                'Total: $totalItems items',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: currentPage < totalPages - 1
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete ${product.meds}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              final productProvider =
                  Provider.of<ProductProvider>(context, listen: false);
              final tenantProvider =
                  Provider.of<TenantProvider>(context, listen: false);
              await productProvider.deleteProduct(
                  product.id, authProvider.currentTenantId!);
              tenantProvider.deleteProduct(
                  authProvider.currentTenantId!, product.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadProducts();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getStatusText(Product product) {
    if (product.isExpired && product.isLowStock) return 'EXPIRED + LOW';
    if (product.isExpired) return 'EXPIRED';
    if (product.isExpiringSoon && product.isLowStock) return 'CRITICAL';
    if (product.isExpiringSoon) return 'EXPIRING SOON';
    if (product.isLowStock) return 'LOW STOCK';
    return 'IN STOCK';
  }

  Color _getStatusColor(Product product) {
    if (product.isExpired && product.isLowStock) return Colors.red.shade900;
    if (product.isExpired) return Colors.red;
    if (product.isExpiringSoon && product.isLowStock)
      return Colors.red.shade700;
    if (product.isExpiringSoon) return Colors.orange;
    if (product.isLowStock) return Colors.orange;
    return Colors.green;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
