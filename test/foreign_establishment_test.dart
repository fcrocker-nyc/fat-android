// Foreign (imported) establishment mark detection.
import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/foreign_establishment.dart';

void main() {
  // Text as it reads on the recalled Ferrarini/Prime Line guanciale package
  // (FSIS recall 019-020-2026): the Italian mark of inspection, no USDA EST.
  const guanciale = '''
FERRARINI GUANCIALE DRY-CURED PORK JOWL
PRODOTTO IN ITALIA / PRODUCT OF ITALY
KEEP REFRIGERATED
IT 1937 L CE
LOT: 263311US   BEST IF USE BY DATE: 05.16.27
INGREDIENTS: PORK JOWL, SALT, SPICES, DEXTROSE, SODIUM NITRATE, SODIUM NITRITE
''';

  test('Italian EU identification mark is decoded', () {
    final f = ForeignEstablishmentDetector.detect(guanciale);
    expect(f, isNotNull);
    expect(f!.countryCode, 'IT');
    expect(f.countryName, 'Italy');
    expect(f.token, 'IT1937L');
    expect(f.display, 'IT 1937 L');
    expect(f.scheme, 'eu');
  });

  test('mark variants OCR-tolerant', () {
    for (final v in ['IT1937L CE', 'IT 1937 L EC', 'IT-1937-L CE']) {
      final f = ForeignEstablishmentDetector.detect(v);
      expect(f, isNotNull, reason: 'should parse "$v"');
      expect(f!.token, 'IT1937L', reason: 'token for "$v"');
    }
  });

  test('other EU countries decode with their own abbreviations', () {
    final pl = ForeignEstablishmentDetector.detect('PL 14161602 WE');
    expect(pl?.countryName, 'Poland');
    expect(pl?.token, 'PL14161602');

    final es = ForeignEstablishmentDetector.detect('JAMON SERRANO ES 1005934 CE');
    expect(es?.countryName, 'Spain');
  });

  test('Brazil SIF and Mexico TIF marks decode', () {
    final br = ForeignEstablishmentDetector.detect('CORNED BEEF SIF 1234');
    expect(br?.countryName, 'Brazil');
    expect(br?.token, 'SIF1234');

    final mx = ForeignEstablishmentDetector.detect('TIF 456 CARNE');
    expect(mx?.countryName, 'Mexico');
    expect(mx?.token, 'TIF456');
  });

  test('a domestic label yields no foreign mark', () {
    const domestic = '''
HORMEL BLACK LABEL BACON
U.S. INSPECTED AND PASSED BY DEPARTMENT OF AGRICULTURE EST. 199
INGREDIENTS: PORK, WATER, SALT, SUGAR, SODIUM NITRITE
''';
    expect(ForeignEstablishmentDetector.detect(domestic), isNull);
  });

  test('ordinary label words do not fire the EU pattern', () {
    for (final s in [
      'GREAT VALUE SLICED BACON NET WT 16 OZ PRICE 4.98',
      'PRODUCE OF USA 12 COUNT PACKAGE',
      'NUTRITION FACTS SERVING SIZE 2 SLICES 28G',
    ]) {
      expect(ForeignEstablishmentDetector.detect(s), isNull,
          reason: 'should not match "$s"');
    }
  });
}
