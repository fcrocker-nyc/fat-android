import 'dart:io';

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
/// the app is not lost. Before the camera opens we remember which scan asked;
/// on the next launch [retrieve] asks image_picker for the lost result
/// (Android only) and hands it back with that scan, so MainShell can reopen
/// the right screen with the photo already in it.
class LostPhotoRecovery {
  static const _pendingKey = 'pendingPhotoScan';

  static Future<XFile?> pickImage(
    PhotoScan scan, {
    required ImageSource source,
    int imageQuality = 90,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, scan.name);
    try {
      return await ImagePicker()
          .pickImage(source: source, imageQuality: imageQuality);
    } finally {
      // Normal return (photo or cancel): nothing to recover.
      await prefs.remove(_pendingKey);
    }
  }

  /// Returns the photo lost to an app restart, or null. Consumes it: a second
  /// call returns null.
  static Future<RecoveredPhoto?> retrieve() async {
    if (!Platform.isAndroid) return null;
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_pendingKey);
    LostDataResponse response;
    try {
      response = await ImagePicker().retrieveLostData();
    } catch (_) {
      return null;
    } finally {
      await prefs.remove(_pendingKey);
    }
    return fromLostData(pending, response);
  }

  /// Pure mapping, split out for tests.
  static RecoveredPhoto? fromLostData(
      String? pendingScan, LostDataResponse response) {
    if (response.isEmpty || response.exception != null) return null;
    final files = response.files ??
        (response.file != null ? [response.file!] : const <XFile>[]);
    if (files.isEmpty) return null;
    final scan = PhotoScan.values
        .where((s) => s.name == pendingScan)
        .firstOrNull;
    // No record of which scan asked (e.g. prefs write lost): the label scan
    // is the primary camera flow, so the photo goes there rather than nowhere.
    return RecoveredPhoto(
        scan ?? PhotoScan.label, files.map((f) => f.path).toList());
  }
}
