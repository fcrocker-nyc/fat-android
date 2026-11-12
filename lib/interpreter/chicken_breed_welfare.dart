// Chicken breed & welfare (Category 3 Breed + Animal Welfare).
//
// For chicken, breed is a welfare determinant, not just a flavor one: a
// broiler's genetics set how fast it grows. Applied to chicken scans only
// (species 'Chicken' — never turkey or duck).
//
//   • Breed: a named slower-growing breed or strain (Poulet Rouge, Freedom
//     Ranger, Red Ranger, Rowdy Ranger, Naked Neck, "slow-growing",
//     "heritage breed") or Cornish Cross counts as disclosed. The existing
//     breed tier logic is unchanged (a producer breed statement carries no
//     credibility chip); only the detail line is added. Cornish Cross is a
//     named breed but is never called slower-growing.
//   • Animal Welfare: when Animal Welfare Approved is on the label, append the
//     growth-rate line (A Greener World meat chicken standard §2.2.5). No
//     status or count change.
//
// Strings are identical to iOS FATAppMVP2/ChickenBreedWelfare.swift.

import '../models/fat_models.dart';

class ChickenBreedWelfare {
  ChickenBreedWelfare._();

  static const String breedWelfareLine =
      'For chicken, breed is a welfare question, not just a flavor one: fast-growing broiler breeds are linked in research to leg, heart and mobility problems.';

  static String namedSlowerGrowingLine(String breed) =>
      'This label names a slower-growing breed ($breed) — the strongest evidence a package can give.';

  static const String noBreedLine = "This label doesn't name the breed.";

  static const String awaGrowthLine =
      "Animal Welfare Approved limits meat chickens' growth to 40 g (0.088 lb) a day, averaged over their lives, unless the breed has passed a recognized welfare assessment. It checks this from breeding-company or hatchery records — so the seal sets a breed requirement but doesn't tell you which breed this farm uses.";

  /// Slower-growing breeds / strains, most specific first. Patterns run on the
  /// lowercased, whitespace-collapsed label text and tolerate OCR spacing /
  /// hyphenation ("freedom-ranger", "freedomranger", "rangers").
  static final List<(RegExp, String)> slowerGrowing = [
    (RegExp(r'\bpoulet[\s-]*rouge\b'), 'Poulet Rouge'),
    (RegExp(r'\bfreedom[\s-]*rangers?\b'), 'Freedom Ranger'),
    (RegExp(r'\bred[\s-]*rangers?\b'), 'Red Ranger'),
    (RegExp(r'\browdy[\s-]*rangers?\b'), 'Rowdy Ranger'),
    (RegExp(r'\bnaked[\s-]*necks?\b'), 'Naked Neck'),
    (RegExp(r'\bslower[\s-]*growing\b'), 'Slower-growing breed'),
    (RegExp(r'\bslow[\s-]*growing\b'), 'Slow-growing breed'),
    (RegExp(r'\bheritage[\s-]*breeds?\b'), 'Heritage breed'),
  ];

  static final RegExp cornishCrossPattern =
      RegExp(r'\bcornish[\s-]*(?:cross|x)\b');

  /// The slower-growing breed named on the label, if any.
  static String? slowerGrowingBreed(String text) {
    for (final (re, display) in slowerGrowing) {
      if (re.hasMatch(text)) return display;
    }
    return null;
  }

  static bool namesCornishCross(String text) => cornishCrossPattern.hasMatch(text);

  /// Rewrites the Breed and Animal Welfare results for a chicken scan.
  /// No-op for any other species.
  static void apply(
    Map<FATCategory, FATCategoryResult> map, {
    required String text,
    required String? species,
  }) {
    if (species != 'Chicken') return;

    // ── Breed (Category 3) ──
    final breed = map[FATCategory.breed] ?? FATCategoryResult.missing;
    final named = slowerGrowingBreed(text);
    if (named != null) {
      map[FATCategory.breed] = FATCategoryResult(
        status: DisclosureStatus.known,
        value: named,
        credibility: breed.credibility,
        credibilityNote: '$breedWelfareLine ${namedSlowerGrowingLine(named)}',
      );
    } else if (namesCornishCross(text)) {
      map[FATCategory.breed] = FATCategoryResult(
        status: DisclosureStatus.known,
        value: 'Cornish Cross',
        credibility: breed.credibility,
        credibilityNote: breedWelfareLine,
      );
    } else if (breed.status == DisclosureStatus.known ||
        breed.status == DisclosureStatus.partial) {
      map[FATCategory.breed] = FATCategoryResult(
        status: breed.status,
        value: breed.value,
        credibility: breed.credibility,
        credibilityNote: breedWelfareLine,
      );
    } else if (breed.status == DisclosureStatus.missing) {
      map[FATCategory.breed] = const FATCategoryResult(
        status: DisclosureStatus.missing,
        credibilityNote: '$breedWelfareLine $noBreedLine',
      );
    }
    // notRequired (prepared-food lane) is left untouched.

    // ── Animal Welfare ──
    final welfare = map[FATCategory.animalWelfare];
    if (text.contains('animal welfare approved') &&
        welfare != null &&
        welfare.status == DisclosureStatus.known) {
      final note = welfare.credibilityNote;
      final base = note == null ? null : (note.endsWith('.') ? note : '$note.');
      map[FATCategory.animalWelfare] = FATCategoryResult(
        status: welfare.status,
        value: welfare.value,
        credibility: welfare.credibility,
        credibilityNote: [?base, awaGrowthLine].join(' '),
        captivityStatus: welfare.captivityStatus,
      );
    }
  }
}

/// Learn topic "Why breed matters for chicken welfare". Text identical to iOS
/// ChickenBreedLearn in FATAppMVP2/ChickenBreedWelfare.swift.
class ChickenBreedLearn {
  ChickenBreedLearn._();

  static const String title = 'Why breed matters for chicken welfare';

  static const String subtitle =
      'Growth rate, the Animal Welfare Approved standard, and what a package can prove';

  static const String body =
      "A chicken's welfare isn't only about how it is housed. Its breed matters too, because breed sets how fast the bird grows. Research links the fast growth of conventional broiler chickens to leg, heart and mobility problems.\n\n"
      "The ASPCA's ShopKind guide reflects this. For chicken, it requires \"healthier breeds\": breeds tested for higher welfare, or breeds that grow less than 45 g a day.\n\n"
      "Animal Welfare Approved sets a growth limit. Its meat chicken standard caps growth at 40 g (0.088 lb) a day, averaged over the bird's life, unless the breed has passed a recognized welfare assessment. Whether a farm meets this is judged from breeding-company or hatchery information, not measured on the farm. So the seal tells you there is a breed requirement, but it doesn't name the strain the farm uses.\n\n"
      'The stronger evidence is a slower-growing breed named on the package itself — for example, Poulet Rouge or Freedom Ranger.\n\n'
      'What FAT shows on a chicken scan:\n'
      '• Breed counts as disclosed when the label names a breed or strain. A named slower-growing breed — such as Poulet Rouge, Freedom Ranger, Red Ranger, Rowdy Ranger or Naked Neck, or a label that says "slow-growing" or "heritage breed" — is noted as the strongest evidence a package can give.\n'
      '• Cornish Cross counts as a named breed, but FAT does not call it slower-growing.\n'
      '• When the label names no breed, the Breed card says so.\n'
      "• When the label carries Animal Welfare Approved, the Animal Welfare card explains the 40 g a day growth limit and that the seal doesn't tell you which breed the farm uses.\n\n"
      'Sources: A Greener World, Animal Welfare Approved meat chicken standards §2.2.5; ASPCA ShopKind criteria; FAT research.';
}
