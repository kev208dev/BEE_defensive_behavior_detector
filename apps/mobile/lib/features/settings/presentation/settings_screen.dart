import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/hive_status.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/connection_badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../alerts/domain/alert_watcher.dart';
import '../../mode_selection/domain/mode_controller.dart';
import '../../monitoring/domain/monitoring_controller.dart';

/// Runtime settings.
///
/// The server address is editable here because at a competition venue the
/// laptop's IP address is not known until the day, and rebuilding the app to
/// change it is not an option.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _baseUrlController;

  @override
  void initState() {
    super.initState();
    _baseUrlController =
        TextEditingController(text: ref.read(baseUrlProvider));
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppMode? mode = ref.watch(appModeProvider);
    final BackendConnectionState connection = ref.watch(connectionProvider);
    final AlertWatcherState watcher = ref.watch(alertWatcherProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: AppSpacing.screen,
        children: <Widget>[
          const SectionHeader(title: '역할'),
          Container(
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    mode?.label ?? '선택되지 않음',
                    style: AppTypography.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: _changeMode,
                  child: const Text('변경'),
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: '서버 주소',
            subtitle: '백엔드가 실행 중인 주소를 입력하세요.',
          ),
          TextField(
            controller: _baseUrlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: AppTypography.bodyLarge,
            decoration: const InputDecoration(
              hintText: AppConfig.apiBaseUrl,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.cardRadius,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: '저장 후 연결 확인',
                  icon: Icons.save_outlined,
                  onPressed: _saveBaseUrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              ConnectionBadge(state: connection),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(connectionProvider.notifier).check(),
                child: const Text('다시 확인'),
              ),
            ],
          ),
          const SectionHeader(title: '동작 설정'),
          const _InfoTile(
            label: '프레임 전송 주기',
            value: '${AppConfig.frameIntervalMs}ms',
          ),
          const _InfoTile(
            label: '오디오 청크 길이',
            value: '${AppConfig.audioChunkSeconds}초',
          ),
          const _InfoTile(
            label: 'Heartbeat 주기',
            value: '${AppConfig.heartbeatIntervalSeconds}초',
          ),
          const _InfoTile(
            label: '경보 폴링 주기',
            value: '${AppConfig.alertPollIntervalSeconds}초',
          ),
          const _InfoTile(
            label: '프레임 최대 해상도',
            value: '${AppConfig.frameMaxDimension}px / '
                'JPEG ${AppConfig.frameJpegQuality}',
          ),
          const _InfoTile(
            label: '데모 모드',
            value: AppConfig.demoMode ? '켜짐 (서버 미사용)' : '꺼짐',
          ),
          _InfoTile(
            label: '경보 감시',
            value: watcher.watching
                ? '동작 중 (새 경보 ${watcher.newAlertCount}건)'
                : '중지됨',
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            '이 값들은 빌드 시 --dart-define 으로 변경할 수 있습니다.',
            style: AppTypography.label,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _saveBaseUrl() async {
    await ref.read(baseUrlProvider.notifier).set(_baseUrlController.text);
    final bool reachable = await ref.read(connectionProvider.notifier).check();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reachable ? '서버에 연결되었습니다.' : '서버에 연결할 수 없습니다. 주소를 확인해주세요.',
        ),
      ),
    );
  }

  Future<void> _changeMode() async {
    // Monitoring must be torn down before the role changes, or the camera
    // would keep running behind the manager UI.
    await ref.read(monitoringControllerProvider.notifier).stopMonitoring();
    ref.read(alertWatcherProvider.notifier).stop();
    await ref.read(appModeProvider.notifier).clear();
    if (!mounted || !context.mounted) return;
    context.go(Routes.mode);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppTypography.bodyMedium)),
          Text(value, style: AppTypography.bodyLarge),
        ],
      ),
    );
  }
}
