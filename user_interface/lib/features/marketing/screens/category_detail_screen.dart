import 'package:flutter/material.dart';
import 'package:phytopi_dashboard/shared/controllers/smooth_scroll_controller.dart';

import '../models/landing_models.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;
  final List<CategoryProduct> products;
  final String? filterTag;

  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
    required this.products,
    this.filterTag,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late final ScrollController _scrollController = SmoothScrollController(
    pointerScrollDuration: const Duration(milliseconds: 260),
    pointerScrollCurve: Curves.easeOutCubic,
    pointerScrollMultiplier: 0.34,
  );

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = widget.filterTag == null
        ? widget.products
        : widget.products.where((product) {
            return product.tags.contains(widget.filterTag);
          }).toList();

    final displayProducts =
        filteredProducts.isEmpty ? widget.products : filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.categoryName} Catalog'),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.filterTag == null
                  ? widget.categoryName
                  : '${widget.categoryName}  ›  ${widget.filterTag}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Explore curated PhytoPi hardware for ${widget.filterTag ?? widget.categoryName}. '
              'All pricing is placeholder for design purposes.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: displayProducts.map((product) {
                return _CategoryProductCard(product: product);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryProductCard extends StatelessWidget {
  final CategoryProduct product;

  const _CategoryProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final showTag = product.tags.isNotEmpty;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withOpacity(0.08),
                child: Icon(product.icon, color: Colors.white, size: 32),
              ),
              if (product.isNew) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Text(
            product.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            product.price,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (showTag) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: product.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('View Product'),
          ),
        ],
      ),
    );
  }
}

