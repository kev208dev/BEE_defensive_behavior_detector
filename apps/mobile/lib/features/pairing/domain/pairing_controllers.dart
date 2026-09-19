import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/errors/pairing_exception.dart';
import '../../../core/models/pairing.dart';
import '../../../core/providers.dart';
import '../data/pairing_repository.dart';

// ======================================================================
// Manager side — issue a code and watch for it to be redeemed
// ======================================================================

/// What the manager's pairing sheet displays.
@immutable
class PairingSheetState {
  const PairingSheetState({
    this.session,
    this.loading = true,
    this.failure,
    this.secondsRemaining = 0,
  });

  final PairingSession? session;
  final bool loading;
  final Failure? failure;

  /// Counted down locally from the server's `expires_in_seconds`, so the
  /// countdown does not depend on the two devices' clocks agreeing.
  final int secondsRemaining;

  bool get isClaimed => session?.status.isClaimed ?? false;
  bool get isExpired =>
      (session?.status.isExpired ?? false) || (session != null && secondsRemaining <= 0);

  /// "09:58"
  String get formattedRemaining {
    final int safe = secondsRemaining < 0 ? 0 : secondsRemaining;
    final String minutes = (safe ~/ 60).toString().padLeft(2, '0');
    final String seconds = (safe % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  PairingSheetState copyWith({
    PairingSession? session,
    bool? loading,
    Failure? failure,
    int? secondsRemaining,
    bool clearFailure = false,
  }) {
    return PairingSheetState(
      session: session ?? this.session,
      loading: loading ?? this.loading,
      failure: clearFailure ? null : (failure ?? this.failure),
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
    );
  }
}

/// Drives the manager's pairing sheet.
///
/// Issues a code, ticks the countdown every second, and polls the backend
/// until a monitoring phone claims it. Both timers are cancelled on dispose —
/// the sheet is transient, and a leaked poll would keep hitting the server
/// after it closed.
///
/// A single controller rather than one per hive: only one sheet is ever open,
/// and [start] rebinds it to whichever hive was tapped.
final NotifierProvider<PairingSheetController, PairingSheetState>
    pairingSheetControllerProvider =
    NotifierProvider<PairingSheetController, PairingSheetState>(
  PairingSheetController.new,
);

class PairingSheetController extends Notifier<PairingSheetState> {
  Timer? _ticker;
  Timer? _poll;
  String? _hiveId;

  /// How often to ask the backend whether the code has been redeemed.
  static const Duration pollInterval = Duration(seconds: 3);

  @override
  PairingSheetState build() {
    ref.onDispose(_stopTimers);
    return const PairingSheetState();
  }

  /// Opens the sheet for [hiveId] and requests the first code.
  Future<void> start(String hiveId) async {
    _hiveId = hiveId;
    state = const PairingSheetState();
    await issueCode();
  }

  /// Requests a fresh code, replacing whatever is on screen.
  Future<void> issueCode() async {
    final String? hiveId = _hiveId;
    if (hiveId == null) return;

    _stopTimers();
    state = state.copyWith(loading: true, clearFailure: true);

    final PairingRepository repository = ref.read(pairingRepositoryProvider);
    try {
      final PairingSession session = await repository.createPairing(hiveId);
      state = PairingSheetState(
        session: session,
        loading: false,
        secondsRemaining: session.expiresInSeconds,
      );
      _startTimers();
    } on Object catch (error, stackTrace) {
      state = state.copyWith(
        loading: false,
        failure: ErrorMapper.map(error, stackTrace),
      );
    }
  }

  void _startTimers() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      final int next = state.secondsRemaining - 1;
      state = state.copyWith(secondsRemaining: next < 0 ? 0 : next);
      // Once it lapses there is nothing left to wait for.
      if (next <= 0) _stopTimers();
    });

    _poll = Timer.periodic(pollInterval, (Timer _) => unawaited(poll()));
  }

  /// One poll cycle. Never throws — a dropped poll just retries next tick.
  Future<void> poll() async {
    final PairingSession? current = state.session;
    if (current == null) return;

    try {
      final PairingSession latest =
          await ref.read(pairingRepositoryProvider).fetchPairing(current.id);
      state = state.copyWith(session: latest, clearFailure: true);
      if (latest.status.isClaimed || latest.status.isExpired) {
        _stopTimers();
      }
    } on Object catch (error) {
      // Leave the code on screen; the monitoring phone may still redeem it.
      debugPrint('PairingSheetController: poll failed — $error');
    }
  }

  void _stopTimers() {
    _ticker?.cancel();
    _ticker = null;
    _poll?.cancel();
    _poll = null;
  }
}

// ======================================================================
// Monitoring side — redeem a code and remember the result
// ======================================================================

/// The hive this phone is paired to, restored from local storage on launch.
///
/// `null` means the phone has never been paired, which is what sends it to
/// the pairing screen instead of monitoring setup.
final NotifierProvider<PairedHiveNotifier, PairedHive?> pairedHiveProvider =
    NotifierProvider<PairedHiveNotifier, PairedHive?>(PairedHiveNotifier.new);

class PairedHiveNotifier extends Notifier<PairedHive?> {
  @override
  PairedHive? build() => ref.read(modeStorageProvider).readPairedHive();

  Future<void> save(PairedHive paired) async {
    await ref.read(modeStorageProvider).writePairedHive(paired);
    state = paired;
  }

  /// Forgets the pairing so the phone can be attached to a different hive.
  Future<void> unpair() async {
    await ref.read(modeStorageProvider).clearPairedHive();
    state = null;
  }
}

/// What the monitoring phone's pairing screen displays.
@immutable
class ClaimState {
  const ClaimState({
    this.submitting = false,
    this.failure,
    this.paired,
  });

  final bool submitting;
  final PairingFailure? failure;

  /// Set once the claim succeeds, which is the screen's cue to move on.
  final PairedHive? paired;

  bool get succeeded => paired != null;

  ClaimState copyWith({
    bool? submitting,
    PairingFailure? failure,
    PairedHive? paired,
    bool clearFailure = false,
  }) {
    return ClaimState(
      submitting: submitting ?? this.submitting,
      failure: clearFailure ? null : (failure ?? this.failure),
      paired: paired ?? this.paired,
    );
  }
}

/// Number of digits in a pairing code.
const int pairingCodeLength = 6;

/// Whether [code] is shaped like a pairing code.
///
/// Used both to enable the submit button and to decide when a scan or a typed
/// code is complete enough to send.
bool isCompletePairingCode(String code) {
  final String compact = code.replaceAll(RegExp(r'[\s-]'), '');
  return compact.length == pairingCodeLength &&
      RegExp(r'^[0-9]+$').hasMatch(compact);
}

final NotifierProvider<ClaimController, ClaimState> claimControllerProvider =
    NotifierProvider<ClaimController, ClaimState>(ClaimController.new);

class ClaimController extends Notifier<ClaimState> {
  @override
  ClaimState build() => const ClaimState();

  /// Clears the error as soon as the beekeeper edits the code again.
  void codeChanged() {
    if (state.failure != null) {
      state = state.copyWith(clearFailure: true);
    }
  }

  /// Redeems [code]. Returns true when the phone is now paired.
  ///
  /// Never throws: every outcome becomes a [PairingFailure] the screen can
  /// render, because a failed pairing must not take the app down in a field.
  Future<bool> submit(String code) async {
    if (state.submitting) return false;

    final String compact = code.replaceAll(RegExp(r'[\s-]'), '');
    if (!isCompletePairingCode(compact)) {
      state = state.copyWith(failure: PairingFailure.invalidCode);
      return false;
    }

    state = state.copyWith(submitting: true, clearFailure: true);
    try {
      final PairedHive paired =
          await ref.read(pairingRepositoryProvider).claim(
                code: compact,
                deviceId: ref.read(deviceIdProvider),
              );
      await ref.read(pairedHiveProvider.notifier).save(paired);
      state = ClaimState(paired: paired);
      return true;
    } on PairingException catch (error) {
      state = ClaimState(failure: error.failure);
      return false;
    } on Object catch (error) {
      debugPrint('ClaimController: claim failed — $error');
      final Failure failure = ErrorMapper.map(error);
      state = ClaimState(
        failure: failure.isConnectivityProblem
            ? PairingFailure.network
            : PairingFailure.unknown,
      );
      return false;
    }
  }

  /// Resets the screen, e.g. when it is reopened after a failure.
  void reset() => state = const ClaimState();
}
