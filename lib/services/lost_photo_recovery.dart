import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The camera scans that can lose a photo when Android kills FAT while the
/// camera app is in front (low memory). Stored by [name], so don't rename.
enum PhotoScan { label, serviceCase, menu }

/// A camera photo recovered after Android restarted FAT, and the scan that
/// asked for it.
class RecoveredPhoto {
  final PhotoScan scan;
  final List<String> paths;
  const RecoveredPhoto(this.scan, this.paths);
}

/// Wraps [ImagePicker.pickImage] so a photo taken just before Android killed
/// the app is not lost. Before the camera opens we remember which scan asked
/// (and when); after the restart [retrieve] asks image_picker for the lost
/// result (Android only) and hands it back with that scan, so MainShell can
/// reopen the right screen with the photo already in it.
///
/// Timing: the relaunched activity gets the camera result, but image_picker
/// writes the photo to its cache from a background thread, so it can land a
/// second or so after MainShell first asks. [retrieve] therefore polls with a
/// short backoff while a scan is pending, and keeps the pending record when
/// nothing has arrived yet (MainShell asks again on resume). The record is
/// cleared only once a photo is delivered, the picker reports an error, or it
/// is older than [staleAfter].
///
/// A recovered photo with no pending record, or a stale one, is discarded:
/// we can't tell which scan took it, and running a menu or placard photo as a
/// label scan (and saving it to History) is worse than asking for a retake.
class LostPhotoRecovery {
  static const pendingKey = 'pendingPhotoScan';
  static const pendingAtKey = 'pendingPhotoScanAt';
  static const staleAfter = Duration(minutes: 30);

  /// Waits between polls while a scan is pending: 3 s in all.
  static const retryDelays = <Duration>[
    Duration(milliseconds: 250),
    Duration(milliseconds: 250),
    Duration(milliseconds: 500),
    Duration(milliseconds: 500),
    Duration(milliseconds: 750),
    Duration(milliseconds: 750),
  ];

  // Seams for tests.
  @visibleForTesting
  static Future<LostDataResponse> Function() lostData = _pluginLostData;
  @visibleForTesting
  static DateTime Function() now = DateTime.now;
  @visibleForTesting
  static Future<void> Function(Duration) wait = _delay;
  @visibleForTesting
  static bool Function() isAndroid = _platformIsAndroid;

  static Future<LostDataResponse> _pluginLostData() =>
      ImagePicker().retrieveLostData();
  static Future<void> _delay(Duration d) => Future<void>.delayed(d);
  static bool _platformIsAndroid() => Platform.isAndroid;

  /// Picks open in this process. Their result comes back through their own
  /// Future, so [retrieve] leaves the pending record alone meanwhile.
  static int _picksInFlight = 0;
  static bool _retrieving = false;

  @visibleForTesting
  static void resetForTest() {
    lostData = _pluginLostData;
    now = DateTime.now;
    wait = _delay;
    isAndroid = _platformIsAndroid;
    _picksInFlight = 0;
    _retrieving = false;
  }

  static Future<XFile?> pickImage(
    PhotoScan scan, {
    required ImageSource source,
    int imageQuality = 90,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingKey, scan.name);
    await prefs.setInt(pendingAtKey, now().millisecondsSinceEpoch);
    _picksInFlight++;
    try {
      return await ImagePicker()
          .pickImage(source: source, imageQuality: imageQuality);
    } finally {
      _picksInFlight--;
      // Normal return (photo, cancel or picker error): nothing to recover.
      await _clearPending(prefs);
    }
  }

  /// Returns the photo lost to an app restart, or null. Safe to call
  /// repeatedly (initState and every resume): a photo is delivered at most
  /// once, and a call that overlaps a running one returns null.
  static Future<RecoveredPhoto?> retrieve() async {
    if (!isAndroid() || _picksInFlight > 0 || _retrieving) return null;
    _retrieving = true;
    try {
      return await _retrieve();
    } finally {
      _retrieving = false;
    }
  }

  static Future<RecoveredPhoto?> _retrieve() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = _freshPendingScan(prefs);
    if (pending == null) {
      // Nothing fresh is waiting. Still drain image_picker's cache once (it
      // clears itself on read) so an orphaned photo can't surface later; it
      // is discarded, never routed.
      final hadStale = prefs.containsKey(pendingKey);
      if (hadStale) await _clearPending(prefs);
      try {
        final r = await lostData();
        if (_hasPhoto(r)) {
          debugPrint('FAT lost-photo: discarded photo with '
              '${hadStale ? 'stale' : 'no'} pending scan');
        }
      } catch (_) {}
      return null;
    }

    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      if (attempt > 0) await wait(retryDelays[attempt - 1]);
      // The user opened the camera again meanwhile: that pick owns the
      // pending record now.
      if (_picksInFlight > 0) return null;
      final LostDataResponse r;
      try {
        r = await lostData();
      } catch (_) {
        continue;
      }
      if (r.exception != null) {
        await _clearPending(prefs);
        debugPrint('FAT lost-photo: picker error ${r.exception?.code}');
        return null;
      }
      final photo = fromLostData(pending.name, r);
      if (photo != null) {
        await _clearPending(prefs);
        debugPrint('FAT lost-photo: delivered to ${photo.scan.name} '
            'on attempt ${attempt + 1}');
        return photo;
      }
    }
    // Not arrived yet (or the user cancelled in the camera). Keep the record:
    // the next resume or launch asks again, until it goes stale.
    debugPrint('FAT lost-photo: ${pending.name} pending, nothing yet');
    return null;
  }

  /// The pending scan, or null if there is none or it is stale.
  static PhotoScan? _freshPendingScan(SharedPreferences prefs) {
    final name = prefs.getString(pendingKey);
    final at = prefs.getInt(pendingAtKey);
    final scan = PhotoScan.values.where((s) => s.name == name).firstOrNull;
    if (scan == null || at == null) return null;
    final age = now().difference(DateTime.fromMillisecondsSinceEpoch(at));
    if (age.isNegative || age > staleAfter) return null;
    return scan;
  }

  static Future<void> _clearPending(SharedPreferences prefs) async {
    await prefs.remove(pendingKey);
    await prefs.remove(pendingAtKey);
  }

  static bool _hasPhoto(LostDataResponse r) =>
      !r.isEmpty &&
      r.exception == null &&
      ((r.files?.isNotEmpty ?? false) || r.file != null);

  /// Pure mapping, split out for tests. Null when there is no photo, or no
  /// known scan to send it to (see the class comment).
  static RecoveredPhoto? fromLostData(
      String? pendingScan, LostDataResponse response) {
    if (!_hasPhoto(response)) return null;
    final scan =
        PhotoScan.values.where((s) => s.name == pendingScan).firstOrNull;
    if (scan == null) return null;
    final files = (response.files?.isNotEmpty ?? false)
        ? response.files!
        : [response.file!];
    return RecoveredPhoto(scan, files.map((f) => f.path).toList());
  }
}
