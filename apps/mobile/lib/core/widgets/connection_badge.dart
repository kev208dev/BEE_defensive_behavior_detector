import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../providers.dart';

/// Shows whether the backend is reachable.
///
/// Takes the state as a parameter rather than reading a provider itself, so
/// it stays a pure presentation widget.
class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({required this.state, this.label, super.key});

  final BackendConnectionState state;

  /// Optional override, e.g. the server address during setup.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon, String text) = switch (state) {
      BackendConnectionState.connected => (
          AppColors.statusNormal,
          Icons.cloud_done_outlined,
          '서버 연결됨',
        ),
      BackendConnectionState.disconnected => (
          AppColors.statusDanger,
          Icons.cloud_off,
          '서버 연결 끊김',
        ),
      BackendConnectionState.unknown => (
          AppColors.textSecondary,
          Icons.cloud_queue,
          '연결 확인 중',
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label ?? text,
          style: AppTypography.label.copyWith(color: color),
        ),
      ],
    );
  }
}
