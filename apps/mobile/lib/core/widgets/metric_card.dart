import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// A single labelled number — risk score, hornet count, and so on.
class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.accent,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;

  /// Overrides the value colour, e.g. to tint by status.
  final Color? accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.metric.copyWith(color: accent),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Text(unit!, style: AppTypography.bodyMedium),
              ],
            ],
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              caption!,
              style: AppTypography.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
