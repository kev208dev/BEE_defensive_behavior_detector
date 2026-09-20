import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../models/alert.dart';
import '../utils/formatters.dart';
import 'status_badge.dart';

/// One alert in the alert list and in the dashboard's recent-alerts section.
class AlertCard extends StatelessWidget {
  const AlertCard({required this.alert, this.onTap, super.key});

  final AlertSummary alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = statusColor(alert.severity.asStatus);

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Container(
          padding: AppSpacing.card,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: AppRadius.cardRadius,
                ),
                child: Icon(
                  statusIcon(alert.severity.asStatus),
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            alert.hiveName,
                            style: AppTypography.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusBadge(
                          status: alert.severity.asStatus,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      alert.message,
                      style: AppTypography.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: <Widget>[
                        Text(
                          '위험도 ${alert.riskScore}',
                          style: AppTypography.label.copyWith(color: accent),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          Formatters.relativeTime(alert.timestamp),
                          style: AppTypography.label,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
