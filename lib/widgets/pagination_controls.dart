// lib/widgets/pagination_controls.dart
import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Function(int) onPageChanged;
  final Function(int) onItemsPerPageChanged;
  final List<int> availableItemsPerPage;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onPrevious,
    required this.onNext,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
    this.availableItemsPerPage = const [10, 25, 50, 100],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Items per page dropdown
          Row(
            children: [
              const Text('Show: ', style: TextStyle(fontSize: 12)),
              DropdownButton<int>(
                value: itemsPerPage,
                items: availableItemsPerPage.map((value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value', style: const TextStyle(fontSize: 12)),
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

          // Page navigation
          Row(
            children: [
              Text(
                'Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: currentPage > 0 ? onPrevious : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: currentPage < totalPages - 1 ? onNext : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
