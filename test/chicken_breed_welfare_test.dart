import 'package:flutter_test/flutter_test.dart';
import 'package:fat_app/interpreter/chicken_breed_welfare.dart';
import 'package:fat_app/interpreter/label_interpreter.dart';
import 'package:fat_app/models/fat_models.dart';

/// Chicken breed & welfare: Category 3 Breed detail line, slower-growing breed
/// detection, and the Animal Welfare Approved growth-rate line. Chicken scans
/// only. Mirrors ChickenBreedWelfareTests.swift.
void main() {
  const always =
      'For chicken, breed is a welfare question, not just a flavor one: fast-growing broiler breeds are linked in research to leg, heart and mobility problems.';
  const noBreed = "This label doesn't name the breed.";
  const awaLine =
      "Animal Welfare Approved limits meat chickens' growth to 40 g (0.088 lb) a day, averaged over their lives, unless the breed has passed a recognized welfare assessment. It checks this from breeding-company or hatchery records — so the seal sets a breed requirement but doesn't tell you which breed this farm uses.";

  Map<FATCategory, FATCategoryResult> cats(String t) =>
      LabelInterpreter.interpret(t);

  test('strings verbatim', () {
    expect(ChickenBreedWelfare.breedWelfareLine, always);
    expect(ChickenBreedWelfare.noBreedLine, noBreed);
    expect(ChickenBreedWelfare.awaGrowthLine, awaLine);
    expect(ChickenBreedWelfare.namedSlowerGrowingLine('Poulet Rouge'),
        'This label names a slower-growing breed (Poulet Rouge) — the strongest evidence a package can give.');
  });

  test('Poulet Rouge → Breed disclosed with slower-growing line', () {
    final breed = cats('JOYCE FARMS\nPOULET ROUGE\nWHOLE CHICKEN\nP-1234')[
        FATCategory.breed]!;
    expect(breed.status, DisclosureStatus.known);
    expect(breed.value, 'Poulet Rouge');
    expect(breed.credibility, isNull); // existing breed tier logic unchanged
    expect(breed.credibilityNote,
        '$always This label names a slower-growing breed (Poulet Rouge) — the strongest evidence a package can give.');
  });

  test('OCR-tolerant strain names', () {
    String? v(String t) => cats(t)[FATCategory.breed]?.value;
    expect(v('whole chicken freedom-rangers'), 'Freedom Ranger');
    expect(v('chicken thighs POULETROUGE'), 'Poulet Rouge');
    expect(v('chicken breast red ranger'), 'Red Ranger');
    expect(v('chicken breast Rowdy Ranger'), 'Rowdy Ranger');
    expect(v('whole chicken naked neck'), 'Naked Neck');
    expect(v('whole chicken slow-growing breed'), 'Slow-growing breed');
    expect(v('whole chicken slower growing'), 'Slower-growing breed');
    expect(v('whole chicken heritage breed'), 'Heritage breed');
  });

  test('no breed → doesn\'t-name-the-breed line', () {
    final breed =
        cats('CHICKEN BREAST\nBONELESS SKINLESS\nP-7091')[FATCategory.breed]!;
    expect(breed.status, DisclosureStatus.missing);
    expect(breed.credibility, isNull);
    expect(breed.credibilityNote, '$always $noBreed');
  });

  test('Animal Welfare Approved → growth-rate line, no status change', () {
    final w = cats('WHOLE CHICKEN\nANIMAL WELFARE APPROVED\nP-1234')[
        FATCategory.animalWelfare]!;
    expect(w.status, DisclosureStatus.known);
    expect(w.value, 'Animal Welfare Approved');
    expect(w.credibility, ClaimCredibility.verified);
    expect(w.credibilityNote, 'Third-party certified by A Greener World. $awaLine');
  });

  test('turkey → none of the chicken lines', () {
    final c = cats('WHOLE TURKEY\nHERITAGE BREED\nANIMAL WELFARE APPROVED\nP-1234');
    expect(c[FATCategory.species]?.value, 'Turkey');
    final breedNote = c[FATCategory.breed]?.credibilityNote ?? '';
    final welfareNote = c[FATCategory.animalWelfare]?.credibilityNote ?? '';
    expect(breedNote.contains('For chicken'), isFalse);
    expect(breedNote.contains('slower-growing'), isFalse);
    expect(breedNote.contains(noBreed), isFalse);
    expect(welfareNote.contains('meat chickens'), isFalse);
    expect(c[FATCategory.animalWelfare]?.credibilityNote,
        'Third-party certified by A Greener World');
  });

  test('Cornish Cross → disclosed without the slower-growing claim', () {
    final breed =
        cats('WHOLE CHICKEN\nCORNISH CROSS\nP-1234')[FATCategory.breed]!;
    expect(breed.status, DisclosureStatus.known);
    expect(breed.value, 'Cornish Cross');
    expect(breed.credibilityNote, always);
    expect(breed.credibilityNote!.contains('slower-growing'), isFalse);
  });

  test('Learn topic is plain language and cites its sources', () {
    expect(ChickenBreedLearn.title, 'Why breed matters for chicken welfare');
    expect(ChickenBreedLearn.body.contains('AWA'), isFalse);
    expect(
        ChickenBreedLearn.body.endsWith(
            'Sources: A Greener World, Animal Welfare Approved meat chicken standards §2.2.5; ASPCA ShopKind criteria; FAT research.'),
        isTrue);
  });
}
