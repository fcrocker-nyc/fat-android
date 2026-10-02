import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

/// "Pasture raised" family (pasture raised / fed / grown, meadow raised, free
/// range, free roaming) on FSIS-inspected labels. FSIS approves these on an
/// inspected label only with producer documentation (FSIS-GD-2024-0006);
/// label approval is a paperwork review, not verification, so — like "Raised
/// Without Antibiotics" and an uncertified "Grass Fed" — the bare claim rates
/// Producer Affidavit. Status never changes; only tier + note. Mirrors
/// PastureFSISTests.swift.
void main() {
  Map<FATCategory, FATCategoryResult> interp(String t) =>
      LabelInterpreter.interpret(t);

  const fsisBeef = 'Ground Beef\nPasture Raised\nRaised Without Antibiotics\n'
      'EST. 45029\nProduct of USA';

  test('FSIS pasture raised → Producer Affidavit in both rows', () {
    final c = interp(fsisBeef);
    expect(c[FATCategory.feed]?.status, DisclosureStatus.known);
    expect(c[FATCategory.feed]?.credibility, ClaimCredibility.producerAffidavit);
    expect(
        c[FATCategory.feed]?.credibilityNote,
        contains(
            'This label uses "pasture raised." FSIS has no regulation defining the term, but it approves the claim on an inspected label only after the producer submits documentation; its 2024 guideline asks for evidence that the animals spent the majority of their lives on pasture, and the label must name who set the standard. Label approval is a paperwork review, not verification: FSIS does not audit the farm or check that the practice continues, so the claim rests on the producer\'s own documentation. No third-party certification mark was found. For beef, bison, lamb, and goat, FAT looks for lifetime pasture or rangeland access with managed grazing and pasture- or range-finishing — not feedlot finishing.'));
    expect(c[FATCategory.animalWelfare]?.status, DisclosureStatus.known);
    expect(c[FATCategory.animalWelfare]?.value, 'Raised Outdoors / Pasture Access');
    expect(c[FATCategory.animalWelfare]?.credibility,
        ClaimCredibility.producerAffidavit);
    expect(c[FATCategory.animalWelfare]?.credibilityNote,
        'The label claims the animal was raised outdoors with pasture (or woodland) access — a meaningful welfare positive versus cage or indoor confinement. FSIS approved the claim after reviewing the producer\'s documentation, but label approval is not verification — FSIS does not audit the farm. No third-party welfare certification (e.g. Certified Humane, Animal Welfare Approved, Global Animal Partnership) was found, so the claim rests on the producer\'s documentation.');
    expect(c[FATCategory.medicine]?.credibility, ClaimCredibility.producerAffidavit);
    expect(c[FATCategory.medicine]?.credibilityNote,
        'FSIS-approved claim based on the producer\'s documentation — label approval is a paperwork review, not an on-farm audit or residue test.');
  });

  test('FSIS gating changes tier only, not status', () {
    final withEst = interp(fsisBeef);
    final noEst = interp(fsisBeef.replaceAll('EST. 45029', ''));
    for (final cat in FATCategory.values) {
      if (cat == FATCategory.usdaFsisRequiredLanguage ||
          cat == FATCategory.processor) {
        continue;
      }
      expect(withEst[cat]?.status, noEst[cat]?.status, reason: '$cat');
    }
    expect(noEst[FATCategory.feed]?.credibility, ClaimCredibility.labelClaimOnly);
    expect(noEst[FATCategory.animalWelfare]?.credibility,
        ClaimCredibility.labelClaimOnly);
  });

  test('No EST pasture raised stays Unverified with new text', () {
    final c = interp('Ground Beef Pasture Raised Product of USA');
    expect(c[FATCategory.feed]?.status, DisclosureStatus.known);
    expect(c[FATCategory.feed]?.credibility, ClaimCredibility.labelClaimOnly);
    final note = c[FATCategory.feed]?.credibilityNote ?? '';
    expect(
        note,
        contains(
            'This label uses "pasture raised" without a third-party certification mark. There is no FSIS regulatory definition of the term, and with no establishment number or inspection legend found on the scanned panels, FAT cannot tie the claim to an FSIS label approval.'));
    expect(note.contains('no audit or monitoring'), isFalse);
    expect(c[FATCategory.animalWelfare]?.credibility,
        ClaimCredibility.labelClaimOnly);
  });

  test('Third-party seal keeps third-party tier', () {
    final c = interp('Chicken Breast Pasture Raised Certified Humane P-20540');
    expect(c[FATCategory.feed]?.credibility, ClaimCredibility.verified);
    expect(c[FATCategory.animalWelfare]?.credibility, ClaimCredibility.verified);
  });

  test('Free range chicken with P-number → Producer Affidavit', () {
    final c = interp('Free Range Chicken Breast P-20540');
    expect(c[FATCategory.feed]?.status, DisclosureStatus.known);
    expect(c[FATCategory.feed]?.credibility, ClaimCredibility.producerAffidavit);
    expect(c[FATCategory.feed]?.credibilityNote,
        contains('This label uses "free range."'));
    expect(c[FATCategory.animalWelfare]?.status, DisclosureStatus.known);
    expect(c[FATCategory.animalWelfare]?.credibility,
        ClaimCredibility.producerAffidavit);
  });

  test('Inspection legend alone counts as FSIS-inspected', () {
    final c = interp(
        'Pork Chops Pasture Raised Inspected and Passed by Department of Agriculture');
    expect(c[FATCategory.feed]?.credibility, ClaimCredibility.producerAffidavit);
    expect(c[FATCategory.animalWelfare]?.credibility,
        ClaimCredibility.producerAffidavit);
  });

  test('Uncertified grass fed on inspected label → Producer Affidavit', () {
    final withEst = interp('Grass Fed Ground Beef EST. 45029');
    expect(withEst[FATCategory.feed]?.status, DisclosureStatus.known);
    expect(withEst[FATCategory.feed]?.credibility,
        ClaimCredibility.producerAffidavit);
    final noEst = interp('Grass Fed Ground Beef');
    expect(noEst[FATCategory.feed]?.status, DisclosureStatus.known);
    expect(noEst[FATCategory.feed]?.credibility, ClaimCredibility.labelClaimOnly);
  });

  test('Hormone/antibiotic claims Producer Affidavit unless PVP', () {
    final plain = interp(
        'Beef Steak No Hormones Administered No Antibiotics Ever EST. 45029');
    expect(plain[FATCategory.hormones]?.status, DisclosureStatus.known);
    expect(plain[FATCategory.hormones]?.credibility,
        ClaimCredibility.producerAffidavit);
    expect(plain[FATCategory.hormones]?.credibilityNote,
        LabelInterpreter.fsisLabelApprovalNote);
    expect(plain[FATCategory.medicine]?.credibility,
        ClaimCredibility.producerAffidavit);
    final pvp = interp('Beef Steak No Hormones Administered USDA Process Verified '
        'Non-Hormone Treated Cattle EST. 45029');
    expect(pvp[FATCategory.hormones]?.status, DisclosureStatus.known);
    expect(pvp[FATCategory.hormones]?.credibility, ClaimCredibility.usdaApproved);
  });

  test('PVP pasture stays USDA Process Verified Program tier', () {
    final c = interp('Ground Beef Pasture Raised USDA Process Verified EST. 45029');
    expect(c[FATCategory.feed]?.credibility, ClaimCredibility.usdaApproved);
  });

  test('Tier display names: meat vs seafood', () {
    expect(ClaimCredibility.usdaApproved.displayName,
        'USDA Process Verified Program');
    expect(ClaimCredibility.usdaApproved.seafoodDisplayName, 'USDA / FDA program');
    expect(ClaimCredibility.producerAffidavit.seafoodDisplayName,
        'Producer Affidavit');
    expect(ClaimCredibility.usdaApproved.name, 'usdaApproved');
  });

  test('New strings stay neutral', () {
    const banned = ['score', 'grade', 'avoid', 'fails', 'poor', 'hides',
        'conceals', 'refuses', 'unsafe', 'unhealthy'];
    final strings = [
      LabelInterpreter.pastureAlertFsisLabelApproved('pasture raised'),
      LabelInterpreter.pastureAlertNoInspectionMark('pasture raised'),
      LabelInterpreter.outdoorWelfareFsisNote,
      LabelInterpreter.fsisLabelApprovalNote,
    ];
    for (final s in strings) {
      for (final w in banned) {
        expect(RegExp('\\b$w\\b').hasMatch(s.toLowerCase()), isFalse,
            reason: '"$w" in: $s');
      }
    }
  });
}
