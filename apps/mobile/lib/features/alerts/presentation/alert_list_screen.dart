import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/models/alert.dart';
import '../../../core/widgets/alert_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../domain/alert_controllers.dart';

/// Recent alerts, newest first.
class AlertListScreen extends ConsumerWidget {
  const AlertListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AlertSummary>> alerts =
        ref.watch(alertListControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('경보 기록')),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(alertListControllerProvider.notifier).refresh(),
        child: alerts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
              ErrorState(
                failure: ErrorMapper.map(error, stackTrace),
                onRetry: () =>
                    ref.read(alertListControllerProvider.notifier).refresh(),
              ),
            ],
          ),
          data: (List<AlertSummary> items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                  const EmptyState(
                    icon: Icons.notifications_none,
                    title: '경보가 없습니다',
                    message: '말벌 활동이 감지되면 이곳에 기록됩니다.',
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.screen,
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                final AlertSummary alert = items[index];
                return AlertCard(
                  alert: alert,
                  onTap: () => context.push(Routes.alert(alert.id)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
