import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/models/hive.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/hive_card.dart';
import '../domain/hive_controllers.dart';

/// Every hive, with its status clearly visible.
class HiveListScreen extends ConsumerWidget {
  const HiveListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Hive>> hives = ref.watch(hiveListControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('벌통 목록')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(hiveListControllerProvider.notifier).refresh(),
        child: hives.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: <Widget>[
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
              ErrorState(
                failure: ErrorMapper.map(error, stackTrace),
                onRetry: () =>
                    ref.read(hiveListControllerProvider.notifier).refresh(),
              ),
            ],
          ),
          data: (List<Hive> items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                  const EmptyState(
                    icon: Icons.hive_outlined,
                    title: '벌통이 없습니다',
                    message: '백엔드에 등록된 벌통이 없습니다.',
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
                final Hive hive = items[index];
                return HiveCard(
                  hive: hive,
                  onTap: () => context.push(Routes.hive(hive.id)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
