import 'package:beehive_guard/core/config/mode_storage.dart';
import 'package:beehive_guard/core/errors/pairing_exception.dart';
import 'package:beehive_guard/core/models/pairing.dart';
import 'package:beehive_guard/core/providers.dart';
import 'package:beehive_guard/features/pairing/data/pairing_repository.dart';
import 'package:beehive_guard/features/pairing/domain/pairing_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A repository whose every outcome the test dictates.
class _FakePairingRepository implements PairingRepository {
  _FakePairingRepository();

  PairingSession? sessionToReturn;
  PairedHive? claimResult;
  Object? claimError;

  final List<String> claimedCodes = <String>[];
  int createCalls = 0;
  int fetchCalls = 0;

  @override
  Future<PairingSession> createPairing(String hiveId) async {
    createCalls++;
    return sessionToReturn ??
        PairingSession(
          id: 'p1',
          code: '482731',
          hiveId: hiveId,
          hiveName: '벌통 A',
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          expiresInSeconds: 600,
          pairUri: buildPairUri('482731'),
        );
  }

  @override
  Future<PairingSession> fetchPairing(String pairingId) async {
    fetchCalls++;
    return sessionToReturn!;
  }

  @override
  Future<PairedHive> claim({
    required String code,
    required String deviceId,
  }) async {
    claimedCodes.add(code);
    if (claimError != null) throw claimError!;
    return claimResult ??
        PairedHive(hiveId: 'hive-a', hiveName: '벌통 A', deviceId: deviceId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _FakePairingRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    repository = _FakePairingRepository();
  });

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        modeStorageProvider.overrideWithValue(ModeStorage(prefs)),
        pairingRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // ------------------------------------------------------------------
  // Code validation
  // ------------------------------------------------------------------

  group('pairing code validation', () {
    test('accepts exactly six digits', () {
      expect(isCompletePairingCode('482731'), isTrue);
    });

    test('rejects short, long and non-numeric codes', () {
      expect(isCompletePairingCode('48273'), isFalse);
      expect(isCompletePairingCode('4827311'), isFalse);
      expect(isCompletePairingCode('48273a'), isFalse);
      expect(isCompletePairingCode(''), isFalse);
    });

    test('tolerates the display spacing', () {
      // The manager screen shows "482 731"; retyping it as shown must work.
      expect(isCompletePairingCode('482 731'), isTrue);
      expect(isCompletePairingCode('482-731'), isTrue);
    });
  });

  group('parsePairCode', () {
    test('reads the deep link a QR code carries', () {
      expect(parsePairCode('beehiveguard://pair?code=482731'), '482731');
    });

    test('reads a bare code, with or without spacing', () {
      expect(parsePairCode('482731'), '482731');
      expect(parsePairCode('482 731'), '482731');
      expect(parsePairCode('  482731  '), '482731');
    });

    test('ignores QR codes that are not ours', () {
      // Pointing the scanner at an unrelated code should do nothing rather
      // than report a failure for every frame.
      expect(parsePairCode('https://example.com'), isNull);
      expect(parsePairCode('beehiveguard://pair?code=abc'), isNull);
      expect(parsePairCode('beehiveguard://pair'), isNull);
      expect(parsePairCode(null), isNull);
      expect(parsePairCode(''), isNull);
    });

    test('round-trips with buildPairUri', () {
      expect(parsePairCode(buildPairUri('123456')), '123456');
    });
  });

  group('PairingSession display', () {
    PairingSession session(String code) => PairingSession(
          id: 'p1',
          code: code,
          hiveId: 'hive-a',
          expiresAt: DateTime.now(),
        );

    test('groups a six-digit code for reading aloud', () {
      expect(session('482731').formattedCode, '482 731');
    });

    test('leaves an unexpected length alone', () {
      expect(session('4827').formattedCode, '4827');
    });

    test('falls back to building the pair URI locally', () {
      // An older backend that sends no pair_uri must still produce a QR.
      expect(session('482731').effectivePairUri, buildPairUri('482731'));
    });
  });

  // ------------------------------------------------------------------
  // Claiming
  // ------------------------------------------------------------------

  group('ClaimController', () {
    test('a successful claim reports the paired hive', () async {
      final ProviderContainer container = makeContainer();

      final bool ok = await container
          .read(claimControllerProvider.notifier)
          .submit('482731');

      expect(ok, isTrue);
      expect(container.read(claimControllerProvider).succeeded, isTrue);
      expect(container.read(claimControllerProvider).paired?.hiveId, 'hive-a');
    });

    test('a successful claim persists the pairing', () async {
      final ProviderContainer container = makeContainer();

      await container.read(claimControllerProvider.notifier).submit('482731');

      final PairedHive? stored = ModeStorage(prefs).readPairedHive();
      expect(stored, isNotNull);
      expect(stored!.hiveId, 'hive-a');
      expect(stored.hiveName, '벌통 A');
    });

    test('strips spacing before sending the code', () async {
      final ProviderContainer container = makeContainer();

      await container.read(claimControllerProvider.notifier).submit('482 731');

      expect(repository.claimedCodes.single, '482731');
    });

    test('an incomplete code never reaches the server', () async {
      final ProviderContainer container = makeContainer();

      final bool ok =
          await container.read(claimControllerProvider.notifier).submit('4827');

      expect(ok, isFalse);
      expect(repository.claimedCodes, isEmpty);
      expect(
        container.read(claimControllerProvider).failure,
        PairingFailure.invalidCode,
      );
    });

    test('surfaces the server reason for an expired code', () async {
      repository.claimError = const PairingException(PairingFailure.expired);
      final ProviderContainer container = makeContainer();

      final bool ok = await container
          .read(claimControllerProvider.notifier)
          .submit('482731');

      expect(ok, isFalse);
      expect(
        container.read(claimControllerProvider).failure,
        PairingFailure.expired,
      );
    });

    test('surfaces an already-claimed code', () async {
      repository.claimError =
          const PairingException(PairingFailure.alreadyClaimed);
      final ProviderContainer container = makeContainer();

      await container.read(claimControllerProvider.notifier).submit('482731');

      expect(
        container.read(claimControllerProvider).failure,
        PairingFailure.alreadyClaimed,
      );
    });

    test('a thrown non-pairing error becomes a typed failure', () async {
      // A dead network must not take the screen down.
      repository.claimError = Exception('boom');
      final ProviderContainer container = makeContainer();

      final bool ok = await container
          .read(claimControllerProvider.notifier)
          .submit('482731');

      expect(ok, isFalse);
      expect(container.read(claimControllerProvider).failure, isNotNull);
      expect(container.read(claimControllerProvider).succeeded, isFalse);
    });

    test('a failed claim leaves nothing persisted', () async {
      repository.claimError = const PairingException(PairingFailure.expired);
      final ProviderContainer container = makeContainer();

      await container.read(claimControllerProvider.notifier).submit('482731');

      expect(ModeStorage(prefs).readPairedHive(), isNull);
    });

    test('editing the code clears the previous error', () async {
      repository.claimError =
          const PairingException(PairingFailure.invalidCode);
      final ProviderContainer container = makeContainer();
      await container.read(claimControllerProvider.notifier).submit('482731');
      expect(container.read(claimControllerProvider).failure, isNotNull);

      container.read(claimControllerProvider.notifier).codeChanged();

      expect(container.read(claimControllerProvider).failure, isNull);
    });
  });

  // ------------------------------------------------------------------
  // Persistence across restarts
  // ------------------------------------------------------------------

  group('paired hive persistence', () {
    test('is empty on a phone that was never paired', () {
      expect(makeContainer().read(pairedHiveProvider), isNull);
    });

    test('survives a restart', () async {
      // Claim in one container...
      final ProviderContainer first = makeContainer();
      await first.read(claimControllerProvider.notifier).submit('482731');

      // ...and a freshly built one, standing in for the next app launch,
      // comes up already paired.
      final ProviderContainer restarted = makeContainer();

      expect(restarted.read(pairedHiveProvider)?.hiveId, 'hive-a');
      expect(restarted.read(pairedHiveProvider)?.hiveName, '벌통 A');
    });

    test('unpair forgets the hive', () async {
      final ProviderContainer container = makeContainer();
      await container.read(claimControllerProvider.notifier).submit('482731');
      expect(container.read(pairedHiveProvider), isNotNull);

      await container.read(pairedHiveProvider.notifier).unpair();

      expect(container.read(pairedHiveProvider), isNull);
      expect(ModeStorage(prefs).readPairedHive(), isNull);
    });

    test('unpair does not survive as stale state after a restart', () async {
      final ProviderContainer container = makeContainer();
      await container.read(claimControllerProvider.notifier).submit('482731');
      await container.read(pairedHiveProvider.notifier).unpair();

      expect(makeContainer().read(pairedHiveProvider), isNull);
    });

    test('re-pairing replaces the previous hive', () async {
      final ProviderContainer container = makeContainer();
      await container.read(claimControllerProvider.notifier).submit('482731');

      repository.claimResult = const PairedHive(
        hiveId: 'hive-b',
        hiveName: '벌통 B',
      );
      container.read(claimControllerProvider.notifier).reset();
      await container.read(claimControllerProvider.notifier).submit('111222');

      expect(container.read(pairedHiveProvider)?.hiveId, 'hive-b');
      expect(ModeStorage(prefs).readPairedHive()?.hiveName, '벌통 B');
    });
  });

  // ------------------------------------------------------------------
  // Manager side
  // ------------------------------------------------------------------

  group('PairingSheetController', () {
    test('issues a code for the requested hive', () async {
      final ProviderContainer container = makeContainer();

      await container
          .read(pairingSheetControllerProvider.notifier)
          .start('hive-a');

      final PairingSheetState state =
          container.read(pairingSheetControllerProvider);
      expect(state.loading, isFalse);
      expect(state.session?.code, '482731');
      expect(state.secondsRemaining, 600);
      expect(repository.createCalls, 1);
    });

    test('reports a failed request instead of throwing', () async {
      // A server that is down must leave the sheet showing a retry, not crash.
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          modeStorageProvider.overrideWithValue(ModeStorage(prefs)),
          pairingRepositoryProvider.overrideWithValue(_FailingRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(pairingSheetControllerProvider.notifier)
          .start('hive-a');

      final PairingSheetState state =
          container.read(pairingSheetControllerProvider);
      expect(state.loading, isFalse);
      expect(state.failure, isNotNull);
    });

    test('a poll showing CLAIMED flips the sheet to connected', () async {
      final ProviderContainer container = makeContainer();
      await container
          .read(pairingSheetControllerProvider.notifier)
          .start('hive-a');

      repository.sessionToReturn = PairingSession(
        id: 'p1',
        code: '482731',
        hiveId: 'hive-a',
        hiveName: '벌통 A',
        status: PairingStatus.claimed,
        claimedDeviceId: 'phone-1',
        expiresAt: DateTime.now().add(const Duration(minutes: 9)),
      );
      await container.read(pairingSheetControllerProvider.notifier).poll();

      expect(container.read(pairingSheetControllerProvider).isClaimed, isTrue);
    });

    test('formats the remaining time as mm:ss', () {
      const PairingSheetState state = PairingSheetState(secondsRemaining: 598);
      expect(state.formattedRemaining, '09:58');

      const PairingSheetState nearly = PairingSheetState(secondsRemaining: 5);
      expect(nearly.formattedRemaining, '00:05');
    });

    test('a lapsed countdown reads as expired', () {
      final PairingSheetState state = PairingSheetState(
        session: PairingSession(
          id: 'p1',
          code: '482731',
          hiveId: 'hive-a',
          expiresAt: DateTime.now(),
        ),
        loading: false,
      );

      expect(state.isExpired, isTrue);
    });
  });

  // ------------------------------------------------------------------
  // Demo repository
  // ------------------------------------------------------------------

  group('DemoPairingRepository', () {
    test('accepts its own code and rejects others', () async {
      final DemoPairingRepository demo = DemoPairingRepository();

      final PairedHive paired = await demo.claim(
        code: DemoPairingRepository.demoCode,
        deviceId: 'phone-1',
      );
      expect(paired.hiveId, DemoPairingRepository.demoHiveId);

      expect(
        () => demo.claim(code: '000000', deviceId: 'phone-1'),
        throwsA(isA<PairingException>()),
      );
    });

    test('reports CLAIMED once its code has been redeemed', () async {
      final DemoPairingRepository demo = DemoPairingRepository();
      await demo.createPairing('hive-a');

      expect(
        (await demo.fetchPairing('demo-pairing')).status,
        PairingStatus.waiting,
      );

      await demo.claim(
        code: DemoPairingRepository.demoCode,
        deviceId: 'phone-1',
      );

      expect(
        (await demo.fetchPairing('demo-pairing')).status,
        PairingStatus.claimed,
      );
    });
  });
}

/// A repository that fails every call, for the sheet's error path.
class _FailingRepository implements PairingRepository {
  @override
  Future<PairingSession> createPairing(String hiveId) async =>
      throw Exception('server down');

  @override
  Future<PairingSession> fetchPairing(String pairingId) async =>
      throw Exception('server down');

  @override
  Future<PairedHive> claim({
    required String code,
    required String deviceId,
  }) async =>
      throw Exception('server down');
}
