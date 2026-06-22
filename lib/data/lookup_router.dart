import 'meat_brand_database.dart';
import 'seafood_brand_database.dart';

/// Auto-detects which lookup a free-text query should run, so the user no
/// longer has to pick EST / Meat / Seafood before typing.
///
/// Returns a tab index matching the Lookup screen's segmented control:
///   0 = EST   1 = Meat Brand   2 = Seafood Brand
class LookupRouter {
  /// Decide which lookup tab a raw query should route to.
  ///
  /// Rules, in order:
  ///   1. Strip a leading "est."/"est" prefix. If what remains is all digits
  ///      (an establishment number), route to EST.
  ///   2. If the query matches a known seafood brand but NOT a meat brand,
  ///      route to Seafood (and vice-versa for meat).
  ///   3. On a tie (matches both) or no match at all, fall back to Meat —
  ///      the larger database and the more common consumer case. The Lookup
  ///      tab still shows the chosen segment, so the user can correct with a
  ///      single tap.
  static int detect(String query) {
    final q = query.trim();
    if (q.isEmpty) return 0;

    // 1. Establishment number — digits only after stripping an "est" prefix.
    final stripped = q
        .replaceAll(RegExp(r'^est\.?\s*', caseSensitive: false), '')
        .trim();
    if (stripped.isNotEmpty && RegExp(r'^\d+$').hasMatch(stripped)) {
      return 0;
    }

    // 2. Brand databases.
    final meatHit = MeatBrandDatabase.search(q).isNotEmpty;
    final seafoodHit = SeafoodBrandDatabase.search(q).isNotEmpty;

    if (seafoodHit && !meatHit) return 2;
    if (meatHit && !seafoodHit) return 1;

    // 3. Tie or miss → Meat brand (correctable on the Lookup tab).
    return 1;
  }
}
