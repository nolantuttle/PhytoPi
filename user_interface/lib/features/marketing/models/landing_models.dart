import 'package:flutter/material.dart';

/// Data model for category mega menu columns.
class CategoryColumnData {
  final String title;
  final List<String> links;

  const CategoryColumnData({
    required this.title,
    required this.links,
  });
}

/// Data model for category detail/product cards.
class CategoryProduct {
  final String title;
  final String description;
  final String price;
  final IconData icon;
  final List<String> tags;
  final bool isNew;

  const CategoryProduct({
    required this.title,
    required this.description,
    required this.price,
    required this.icon,
    this.tags = const [],
    this.isNew = false,
  });
}

