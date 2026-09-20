import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../models/hive_status.dart';

/// Maps a [HiveStatus] onto its token colour.
///
/// Every place that colours something by status goes through here, so the
/// mapping changes in exactly one place when the design does.
Color statusColor(HiveStatus status) => switch (status) {
      HiveStatus.normal => AppColors.statusNormal,
      HiveStatus.caution => AppColors.statusCaution,
      HiveStatus.danger => AppColors.statusDanger,
      HiveStatus.offline => AppColors.statusOffline,
    };

IconData statusIcon(HiveStatus status) => switch (status) {
      HiveStatus.normal => Icons.check_circle_outline,
      HiveStatus.caution => Icons.warning_amber_rounded,
      HiveStatus.danger => Icons.crisis_alert,
      HiveStatus.offline => Icons.cloud_off,
    };

/// A coloured pill showing a hive's status.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.status,
    this.compact = false,
    super.key,
  });

  final HiveStatus status;

  /// Drops the icon, for tight rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color color = statusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!compact) ...<Widget>[
            Icon(statusIcon(status), size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            status.label,
            style: AppTypography.label.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
