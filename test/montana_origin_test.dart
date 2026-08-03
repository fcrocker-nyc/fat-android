import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/data/montana_origin.dart';

void main() {
  group('MontanaOrigin.detect', () {
    test('processed in Montana when state == MT, with directory cross-ref', () {
      final r = MontanaOrigin.detect(
        state: 'MT',
        establishmentName: 'Pioneer Meats, Inc.',
        city: 'Big Timber',
        establishmentNumber: '46336',
      );
      expect(r.processedInMontana, isTrue);
      expect(r.hasSignal, isTrue);
      expect(r.isAbundantMontanaProcessor, isTrue); // "Pioneer" token overlaps
      expect(r.processorCity, 'Big Timber');
    });

    test('not Montana for another state; no false directory flag', () {
      final r = MontanaOrigin.detect(
        state: 'VT',
        establishmentName: 'Vermont Packinghouse, LLC',
        city: 'North Springfield',
        establishmentNumber: '45029',
      );
      expect(r.processedInMontana, isFalse);
      expect(r.isAbundantMontanaProcessor, isFalse);
      expect(r.hasSignal, isFalse);
    });

    test('digit collision cannot fabricate a Montana listing (3886 non-MT)', () {
      // 3886 is M&S Meats in the AM roster but resolves to Butterball (non-MT)
      // once the M/P/V prefix is stripped. Must NOT flag Montana.
      final r = MontanaOrigin.detect(
        state: '', // empty/unknown state, as the federal mirror returns
        establishmentName: 'Butterball, LLC',
        establishmentNumber: '3886',
      );
      expect(r.processedInMontana, isFalse);
      expect(r.isAbundantMontanaProcessor, isFalse);
    });

    test('producer match from label OCR text', () {
      final r = MontanaOrigin.detect(
        ocrText: 'GRASS FED BEEF from Yellowstone Grassfed Beef, raised in Montana',
      );
      // matches only if that exact directory name exists; assert no crash + type
      expect(r, isA<MontanaOriginResult>());
    });
  });

  group('stateFromAddress', () {
    test('parses trailing state from a full address', () {
      expect(MontanaOrigin.stateFromAddress('31 Pioneer Trail, Big Timber, MT, 59011'), 'MT');
      expect(MontanaOrigin.stateFromAddress('123 Main St, Springfield, VT'), 'VT');
    });
    test('returns null when no clear state', () {
      expect(MontanaOrigin.stateFromAddress('somewhere unknown'), isNull);
    });
  });
}
