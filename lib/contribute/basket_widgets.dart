import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../models/basket_donation.dart';

/// Widgets compartilhados entre as telas de "Doe para Cestas Básicas"
/// (04/09/2026) — evita duplicar o selo de prioridade e o card "Onde e
/// quando entregar?" em cada uma delas.
class BasketPriorityBadge extends StatelessWidget {
  const BasketPriorityBadge({super.key, required this.priority});

  final BasketPriority priority;

  Color get _color => switch (priority) {
    BasketPriority.alta => Colors.red,
    BasketPriority.media => Colors.orange,
    BasketPriority.baixa => Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class BasketDeliveryInfoCard extends StatelessWidget {
  const BasketDeliveryInfoCard({super.key, required this.deliveryInfo});

  final String deliveryInfo;

  @override
  Widget build(BuildContext context) {
    if (deliveryInfo.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: SibValColors.goldAccent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Onde e quando entregar?',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    deliveryInfo,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
