import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

/// FSIS poultry class names (9 CFR 381.170 — Broiler, Fryer, Roaster, Capon,
/// Cornish Game Hen, Stewing Hen / Fowl) are an FSIS naming standard, not an
/// audited program. They still count Known on Age at Slaughter and keep their
/// internal tier (so the behind-the-scenes index does not move), but they
/// DISPLAY like the other required label basics: no credibility tier chip,
/// just the neutral class-name line. Mirrors FSISClassNameTests.swift.
void main() {
  const broiler = 'BROILER\nCHICKEN BREAST\nP-7091\n'
      'INSPECTED FOR WHOLESOMENESS BY U.S. DEPARTMENT OF AGRICULTURE';
  const broilerPvp = 'BROILER\nWHOLE CHICKEN\nUSDA PROCESS VERIFIED\n'
      'NO ANTIBIOTICS EVER\nP-7091\n'
      'INSPECTED FOR WHOLESOMENESS BY U.S. DEPARTMENT OF AGRICULTURE';

  test('BROILER with P-number: status unchanged, no PVP chip, neutral line', () {
    final c = LabelInterpreter.interpret(broiler);
    final r = FATResult(scannedText: broiler, categories: c);
    final age = c[FATCategory.ageAtSlaughter]!;
    // Category status + disclosure count exactly as before the change.
    expect(age.status, DisclosureStatus.known);
    expect(age.value, 'Broiler / Fryer — < 10 weeks old (9 CFR 381.170)');
    expect(r.knownCount, 4);
    expect(r.partialCount, 0);
    // Stored tier kept → behind-the-scenes index unchanged (37.47 pre-change).
    expect(age.credibility, ClaimCredibility.usdaApproved);
    expect(r.fatScore, closeTo(37.4706, 0.001));
    // Display: no tier chip / label, neutral line instead.
    expect(age.isFsisClassName, isTrue);
    expect(age.displayCredibility, isNull);
    expect(age.credibilityNote, startsWith(FATCategoryResult.fsisClassNameLine));
    expect(FATCategoryResult.fsisClassNameLine,
        'FSIS class name (9 CFR 381.170) — a required naming standard that implies an age range, not a verified claim.');
    // No category displays "USDA Process Verified Program" on this label.
    expect(
        c.values.where(
            (v) => v.displayCredibility == ClaimCredibility.usdaApproved),
        isEmpty);
  });

  test('every class name drops the chip and keeps Known', () {
    for (final t in [
      'cornish game hen',
      'stewing hen',
      'chicken fowl',
      'capon breast',
      'roaster chicken',
      'fryer chicken',
    ]) {
      final age = LabelInterpreter.interpret(t)[FATCategory.ageAtSlaughter]!;
      expect(age.status, DisclosureStatus.known, reason: t);
      expect(age.credibility, ClaimCredibility.usdaApproved, reason: t);
      expect(age.displayCredibility, isNull, reason: t);
      expect(age.credibilityNote,
          startsWith(FATCategoryResult.fsisClassNameLine), reason: t);
    }
  });

  test('class name + PVP: the PVP tier still shows', () {
    final c = LabelInterpreter.interpret(broilerPvp);
    final age = c[FATCategory.ageAtSlaughter]!;
    expect(age.status, DisclosureStatus.known);
    expect(age.displayCredibility, isNull);
    final med = c[FATCategory.medicine]!;
    expect(med.status, DisclosureStatus.known);
    expect(med.credibility, ClaimCredibility.usdaApproved);
    expect(med.displayCredibility, ClaimCredibility.usdaApproved);
    expect(med.displayCredibility!.displayName, 'USDA Process Verified Program');
  });

  test('a non-class-name usdaApproved result is unaffected', () {
    const r = FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Tyson Foods',
        credibility: ClaimCredibility.usdaApproved);
    expect(r.isFsisClassName, isFalse);
    expect(r.displayCredibility, ClaimCredibility.usdaApproved);
  });

  test('new string stays neutral', () {
    const banned = ['score', 'grade', 'avoid', 'fails', 'poor', 'hides',
        'conceals', 'refuses', 'unsafe', 'unhealthy'];
    final s = FATCategoryResult.fsisClassNameLine.toLowerCase();
    for (final w in banned) {
      expect(RegExp('\\b$w\\b').hasMatch(s), isFalse, reason: w);
    }
  });
}
