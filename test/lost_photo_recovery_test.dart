import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fat_app/services/lost_photo_recovery.dart';

void main() {
  LostDataResponse lost(List<String> paths) => LostDataResponse(
        file: XFile(paths.first),
        files: paths.map(XFile.new).toList(),
        type: RetrieveType.image,
      );

  group('fromLostData', () {
    test('nothing lost → null', () {
      expect(LostPhotoRecovery.fromLostData('menu', LostDataResponse.empty()),
          isNull);
    });

    test('picker error → null', () {
      final r = LostDataResponse(
        exception: PlatformException(code: 'camera_access_denied'),
        type: RetrieveType.image,
      );
      expect(LostPhotoRecovery.fromLostData('label', r), isNull);
    });

    test('photo goes back to the scan that asked for it', () {
      for (final scan in PhotoScan.values) {
        final r =
            LostPhotoRecovery.fromLostData(scan.name, lost(['/tmp/a.jpg']));
        expect(r?.scan, scan);
        expect(r?.paths, ['/tmp/a.jpg']);
      }
    });

    test('every recovered file is kept', () {
      final r = LostPhotoRecovery.fromLostData(
          'menu', lost(['/tmp/a.jpg', '/tmp/b.jpg']));
      expect(r?.paths, ['/tmp/a.jpg', '/tmp/b.jpg']);
    });

    test('unknown or missing scan → discarded, not run as a label scan', () {
      expect(LostPhotoRecovery.fromLostData(null, lost(['/tmp/a.jpg'])),
          isNull);
      expect(LostPhotoRecovery.fromLostData('gone', lost(['/tmp/a.jpg'])),
          isNull);
    });
  });

  group('retrieve', () {
    final t0 = DateTime(2026, 10, 18, 12);
    late DateTime clock;
    late List<Duration> waits;
    late int calls;

    /// Simulates image_picker's cache: empty until [arriveOnCall], then the
    /// photo once (the plugin clears its cache on read).
    void cache({int arriveOnCall = 1, List<String> paths = const ['/p.jpg']}) {
      var delivered = false;
      LostPhotoRecovery.lostData = () async {
        calls++;
        if (!delivered && calls >= arriveOnCall) {
          delivered = true;
          return lost(paths);
        }
        return LostDataResponse.empty();
      };
    }

    Future<void> pending(PhotoScan scan, {Duration age = Duration.zero}) async {
      SharedPreferences.setMockInitialValues({
        LostPhotoRecovery.pendingKey: scan.name,
        LostPhotoRecovery.pendingAtKey:
            t0.subtract(age).millisecondsSinceEpoch,
      });
    }

    Future<String?> pendingName() async =>
        (await SharedPreferences.getInstance())
            .getString(LostPhotoRecovery.pendingKey);

    setUp(() {
      LostPhotoRecovery.resetForTest();
      clock = t0;
      waits = [];
      calls = 0;
      LostPhotoRecovery.isAndroid = () => true;
      LostPhotoRecovery.now = () => clock;
      LostPhotoRecovery.wait = (d) async {
        waits.add(d);
        clock = clock.add(d);
      };
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(LostPhotoRecovery.resetForTest);

    test('photo already cached → delivered on the first try', () async {
      await pending(PhotoScan.menu);
      cache(arriveOnCall: 1);
      final r = await LostPhotoRecovery.retrieve();
      expect(r?.scan, PhotoScan.menu);
      expect(r?.paths, ['/p.jpg']);
      expect(waits, isEmpty);
      expect(await pendingName(), isNull);
    });

    test('empty response keeps the pending scan', () async {
      await pending(PhotoScan.serviceCase);
      cache(arriveOnCall: 1 << 30); // never arrives
      expect(await LostPhotoRecovery.retrieve(), isNull);
      expect(await pendingName(), 'serviceCase');
      // Bounded: one try plus every backoff step, ~3 s.
      expect(calls, LostPhotoRecovery.retryDelays.length + 1);
      final total = waits.fold(Duration.zero, (a, b) => a + b);
      expect(total, const Duration(seconds: 3));
    });

    test('delayed arrival is delivered to the scan that asked', () async {
      for (final scan in PhotoScan.values) {
        calls = 0;
        await pending(scan);
        cache(arriveOnCall: 4); // lands ~1 s after the first ask
        final r = await LostPhotoRecovery.retrieve();
        expect(r?.scan, scan, reason: scan.name);
        expect(calls, 4);
        expect(await pendingName(), isNull);
      }
    });

    test('arrival after the poll window → delivered on the next call (resume)',
        () async {
      await pending(PhotoScan.menu);
      cache(arriveOnCall: LostPhotoRecovery.retryDelays.length + 2);
      expect(await LostPhotoRecovery.retrieve(), isNull);
      expect(await pendingName(), 'menu');
      final r = await LostPhotoRecovery.retrieve();
      expect(r?.scan, PhotoScan.menu);
    });

    test('no double delivery', () async {
      await pending(PhotoScan.label);
      cache(arriveOnCall: 1);
      expect((await LostPhotoRecovery.retrieve())?.scan, PhotoScan.label);
      expect(await LostPhotoRecovery.retrieve(), isNull);
      expect(await LostPhotoRecovery.retrieve(), isNull);
    });

    test('overlapping calls (initState + resume) deliver once', () async {
      await pending(PhotoScan.menu);
      cache(arriveOnCall: 3);
      final results = await Future.wait(
          [LostPhotoRecovery.retrieve(), LostPhotoRecovery.retrieve()]);
      expect(results.whereType<RecoveredPhoto>().length, 1);
      expect(results.whereType<RecoveredPhoto>().single.scan, PhotoScan.menu);
    });

    test('stale pending is cleared and its photo discarded', () async {
      await pending(PhotoScan.menu, age: const Duration(minutes: 31));
      cache(arriveOnCall: 1);
      expect(await LostPhotoRecovery.retrieve(), isNull);
      expect(await pendingName(), isNull);
      expect(calls, 1, reason: 'cache drained once, no polling');
      expect(waits, isEmpty);
    });

    test('pending just inside 30 min is still delivered', () async {
      await pending(PhotoScan.serviceCase, age: const Duration(minutes: 29));
      cache(arriveOnCall: 1);
      expect((await LostPhotoRecovery.retrieve())?.scan,
          PhotoScan.serviceCase);
    });

    test('pending without a timestamp (pre-fix record) counts as stale',
        () async {
      SharedPreferences.setMockInitialValues(
          {LostPhotoRecovery.pendingKey: 'menu'});
      cache(arriveOnCall: 1);
      expect(await LostPhotoRecovery.retrieve(), isNull);
      expect(await pendingName(), isNull);
    });

    test('no pending: cached photo is drained and discarded, not labelled',
        () async {
      cache(arriveOnCall: 1);
      expect(await LostPhotoRecovery.retrieve(), isNull);
      expect(calls, 1);
      expect(waits, isEmpty);
      // Drained: a later launch with a fresh pending can't pick it up.
      await pending(PhotoScan.label);
      expect(await LostPhotoRecovery.retrieve(), isNull);
    });

    test('picker error clears pending', () async {
      await pending(PhotoScan.label);
      LostPhotoRecovery.lostData = () async => LostDataResponse(
            exception: PlatformException(code: 'no_available_camera'),
            type: RetrieveType.image,
          );
      expect(await LostPhotoRecovery.retrieve(), isNull);
      expect(await pendingName(), isNull);
    });

    test('plugin throwing is retried, then pending kept', () async {
      await pending(PhotoScan.menu);
      LostPhotoRecovery.lostData = () async {
        calls++;
        throw PlatformException(code: 'channel-error');
      };
      expect(await LostPhotoRecovery.retrieve(), isNull);
      expect(calls, LostPhotoRecovery.retryDelays.length + 1);
      expect(await pendingName(), 'menu');
    });

    test('not Android → no-op', () async {
      await pending(PhotoScan.menu);
      cache(arriveOnCall: 1);
      LostPhotoRecovery.isAndroid = () => false;
      expect(await LostPhotoRecovery.retrieve(), isNull);
      expect(calls, 0);
      expect(await pendingName(), 'menu');
    });
  });
}
