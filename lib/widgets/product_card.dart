import 'package:flutter/material.dart';
import '../models/matcha_product.dart';

class ProductCard extends StatelessWidget {
  final MatchaProduct product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isUnavailable = !product.isInStock || product.isDiscontinued;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: isUnavailable ? 1 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: isUnavailable ? 0.6 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isUnavailable ? Colors.grey[50] : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isUnavailable ? Colors.grey[600] : null,
                            decoration:
                                product.isDiscontinued
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusChip(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.store, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        product.site,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const Spacer(),
                      if (product.price != null) ...[
                        Icon(
                          Icons.attach_money,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        Text(
                          product.price!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration:
                                product.isDiscontinued
                                    ? TextDecoration.lineThrough
                                    : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product.category != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.category!,
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Last checked: ${_formatDateTime(product.lastChecked)}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const Spacer(),
                      if (product.firstSeen != product.lastChecked)
                        Text(
                          'Added ${_formatDateTime(product.firstSeen)}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color chipColor;
    IconData chipIcon;
    String chipText;

    if (product.isDiscontinued) {
      chipColor = Colors.grey[700]!;
      chipIcon = Icons.not_interested;
      chipText = 'Discontinued';
    } else if (product.isInStock) {
      chipColor = Colors.green;
      chipIcon = Icons.check_circle;
      chipText = 'In Stock';
    } else {
      chipColor = Colors.red;
      chipIcon = Icons.cancel;
      chipText = 'Out of Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            chipText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
