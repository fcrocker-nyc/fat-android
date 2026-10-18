import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fat_app/services/lost_photo_recovery.dart';

void main() {
  LostDataResponse lost(List<String> paths) => LostDataResponse(
        file: XFile(paths.first),
        files: paths.map(XFile.new).toList(),
        type: RetrieveType.image,
      );

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
      final r = LostPhotoRecovery.fromLostData(scan.name, lost(['/tmp/a.jpg']));
      expect(r?.scan, scan);
      expect(r?.paths, ['/tmp/a.jpg']);
    }
  });

  test('every recovered file is kept', () {
    final r = LostPhotoRecovery.fromLostData(
        'menu', lost(['/tmp/a.jpg', '/tmp/b.jpg']));
    expect(r?.paths, ['/tmp/a.jpg', '/tmp/b.jpg']);
  });

  test('unknown or missing scan falls back to the label scan', () {
    expect(LostPhotoRecovery.fromLostData(null, lost(['/tmp/a.jpg']))?.scan,
        PhotoScan.label);
    expect(LostPhotoRecovery.fromLostData('gone', lost(['/tmp/a.jpg']))?.scan,
        PhotoScan.label);
  });
}
