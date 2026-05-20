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
  List<String> _categories = [];

  // Pagination variables
  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage;
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  int _currentPage = 0;
  final int _itemsPerPage = 10;

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
    _categories =
        productProvider.products.map((p) => p.category).toSet().toList();
    _categories.sort();
    _categories.insert(0, 'All Categories');
    setState(() {});
  }

  void _sortProducts(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  List<Product> _getSortedProducts(List<Product> products) {
    final List<Product> sortedList = List.from(products);
    sortedList.sort((a, b) {
      switch (_sortColumnIndex) {
        case 0: // Meds
          return _sortAscending
              ? a.meds.compareTo(b.meds)
              : b.meds.compareTo(a.meds);
        case 1: // Brand
          return _sortAscending
              ? a.brand.compareTo(b.brand)
              : b.brand.compareTo(a.brand);
        case 2: // Category
          return _sortAscending
              ? a.category.compareTo(b.category)
              : b.category.compareTo(a.category);
        case 3: // Lot Number
          return _sortAscending
              ? a.lotNumber.compareTo(b.lotNumber)
              : b.lotNumber.compareTo(a.lotNumber);
        case 4: // Quantity
          return _sortAscending
              ? a.qty.compareTo(b.qty)
              : b.qty.compareTo(a.qty);
        case 5: // SRP
          return _sortAscending
              ? a.srp.compareTo(b.srp)
              : b.srp.compareTo(a.srp);
        case 6: // Status
          return _sortAscending
              ? a.stockStatus.compareTo(b.stockStatus)
              : b.stockStatus.compareTo(a.stockStatus);
        default:
          return 0;
      }
    });
    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final isAdmin = authProvider.isAdmin;

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

    // Get filtered products
    var filteredProducts = productProvider.getFilteredProducts(
      search: _searchController.text.isEmpty ? null : _searchController.text,
      category:
          _selectedCategory.isEmpty || _selectedCategory == 'All Categories'
              ? null
              : _selectedCategory,
      sortBy: _selectedSort,
    );

    final sortedProducts = _getSortedProducts(filteredProducts);

    // Paginate
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage) > sortedProducts.length
        ? sortedProducts.length
        : startIndex + _itemsPerPage;
    final pageProducts = sortedProducts.sublist(startIndex, endIndex);
    final totalPages = sortedProducts.isEmpty
        ? 1
        : (sortedProducts.length / _itemsPerPage).ceil();

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
                            setState(() {});
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
                      value: _selectedCategory.isEmpty
                          ? 'All Categories'
                          : _selectedCategory,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _categories
                          .map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value ?? '';
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSort,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                        setState(() {
                          _selectedSort = value!;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                ],
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

        // Products Table or Grid
        Expanded(
          child: filteredProducts.isEmpty
              ? const Center(child: Text('No products found'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: PaginatedDataTable(
                                  header: const Text(
                                    'Inventory Management',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  rowsPerPage: _rowsPerPage,
                                  availableRowsPerPage: const [
                                    5,
                                    10,
                                    25,
                                    50,
                                    100
                                  ],
                                  onRowsPerPageChanged: (value) {
                                    setState(() {
                                      _rowsPerPage = value ??
                                          PaginatedDataTable.defaultRowsPerPage;
                                      _currentPage = 0;
                                    });
                                  },
                                  sortColumnIndex: _sortColumnIndex,
                                  sortAscending: _sortAscending,
                                  columns: [
                                    DataColumn(
                                      label: const Text('Meds'),
                                      onSort: _sortProducts,
                                    ),
                                    const DataColumn(label: Text('Brand')),
                                    const DataColumn(label: Text('Category')),
                                    const DataColumn(label: Text('Lot#')),
                                    DataColumn(
                                      label: const Text('Qty'),
                                      numeric: true,
                                      onSort: _sortProducts,
                                    ),
                                    const DataColumn(label: Text('UOM')),
                                    DataColumn(
                                      label: const Text('SRP'),
                                      numeric: true,
                                      onSort: _sortProducts,
                                    ),
                                    const DataColumn(label: Text('Status')),
                                    if (isAdmin)
                                      const DataColumn(label: Text('Actions')),
                                  ],
                                  source: ProductDataSource(
                                    products: pageProducts,
                                    totalCount: sortedProducts.length,
                                    isAdmin: isAdmin,
                                    context: context,
                                    onProductChanged: _loadProducts,
                                    onDelete: (p) => _showDeleteDialog(p),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Pagination controls
                          if (sortedProducts.length > _itemsPerPage)
                            _buildPaginationControls(
                              currentPage: _currentPage,
                              totalPages: totalPages,
                              totalItems: sortedProducts.length,
                              itemsPerPage: _itemsPerPage,
                              onPageChanged: (page) {
                                setState(() {
                                  _currentPage = page;
                                });
                              },
                            ),
                        ],
                      );
                    } else {
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return _buildProductCard(product, isAdmin);
                        },
                      );
                    }
                  },
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${currentPage * itemsPerPage + 1} to ${(currentPage + 1) * itemsPerPage > totalItems ? totalItems : (currentPage + 1) * itemsPerPage} of $totalItems items',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: currentPage > 0
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(
                'Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                style: const TextStyle(fontSize: 12),
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

  Widget _buildProductCard(Product product, bool isAdmin) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image Placeholder
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child:
                Icon(Icons.medication, size: 40, color: Colors.grey.shade400),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.meds,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.brand,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: product.stockStatusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      product.stockStatusText,
                      style: TextStyle(
                        fontSize: 10,
                        color: product.stockStatusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Qty',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey.shade600)),
                          Text('${product.qty} ${product.uom}',
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SRP',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey.shade600)),
                          Text('₱${product.srp}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Expiry',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey.shade600)),
                          Text(
                            _formatDate(product.expirationDate),
                            style: TextStyle(
                              fontSize: 10,
                              color: product.isExpired || product.isExpiringSoon
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddEditProductScreen(product: product),
                              ),
                            );
                            if (result == true) {
                              _loadProducts();
                            }
                          },
                          color: Colors.blue,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: () => _showDeleteDialog(product),
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// ProductDataSource for PaginatedDataTable
class ProductDataSource extends DataTableSource {
  final List<Product> products;
  final int totalCount;
  final bool isAdmin;
  final BuildContext context;
  final VoidCallback onProductChanged;
  final Function(Product) onDelete;

  ProductDataSource({
    required this.products,
    required this.totalCount,
    required this.isAdmin,
    required this.context,
    required this.onProductChanged,
    required this.onDelete,
  });

  @override
  DataRow? getRow(int index) {
    if (index >= products.length) return null;
    final product = products[index];

    return DataRow(
      cells: [
        DataCell(Text(product.meds,
            style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(product.brand)),
        DataCell(Text(product.category)),
        DataCell(Text(product.lotNumber,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
        DataCell(Text('${product.qty}')),
        DataCell(Text(product.uom)),
        DataCell(Text('₱${product.srp.toStringAsFixed(2)}')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: product.stockStatusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              product.stockStatusText,
              style: TextStyle(
                fontSize: 11,
                color: product.stockStatusColor,
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
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditProductScreen(product: product),
                      ),
                    );
                    if (result == true) {
                      onProductChanged();
                    }
                  },
                  color: Colors.blue,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () => onDelete(product),
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => products.length;

  @override
  int get selectedRowCount => 0;
}
