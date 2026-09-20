import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme/app_theme.dart';

/// The application root.
///
/// Deliberately tiny: it wires the router and the theme and nothing else, so
/// that swapping the design in later touches only `theme/` and `widgets/`.
class BeehiveGuardApp extends ConsumerWidget {
  const BeehiveGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '벌통 지킴이',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      routerConfig: router,
    );
  }
}
