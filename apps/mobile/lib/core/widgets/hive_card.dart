import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../models/hive.dart';
import '../utils/formatters.dart';
import 'status_badge.dart';

/// One hive in the dashboard and hive list.
class HiveCard extends StatelessWidget {
  const HiveCard({required this.hive, this.onTap, super.key});

  final Hive hive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = statusColor(hive.status);

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
            border: Border.all(color: AppColors.outline),
            // A coloured left edge makes the status readable at a glance,
            // which is what a beekeeper scanning a list actually needs.
            gradient: LinearGradient(
              colors: <Color>[accent.withValues(alpha: 0.10), Colors.transparent],
              stops: const <double>[0, 0.35],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          hive.name,
                          style: AppTypography.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hive.location.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            hive.location,
                            style: AppTypography.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(status: hive.status),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  _Stat(
                    label: '위험도',
                    value: '${hive.riskScore}',
                    accent: accent,
                  ),
                  _Stat(label: '말벌', value: '${hive.hornetCount}마리'),
                  _Stat(
                    label: '갱신',
                    value: Formatters.relativeTime(hive.lastUpdated),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppTypography.label),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(color: accent),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
