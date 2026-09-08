// ProductTypeDetector — Flutter port of iOS Producttypedetector.swift.
// Scored meat-vs-seafood routing for a scanned label. Weighs strong (+3) and
// weak (+1) signals on each side, treats the USDA/FSIS inspection legend as a
// definitive meat signal (FDA seafood never carries one; Siluriformes/catfish
// is the FSIS-regulated exception), and defaults ambiguous text to meat.
//
// This is the single routing authority: SeafoodInterpreter.isSeafood and the
// scan screen both delegate here, so the keyword lists can no longer drift
// between the router and the interpreter (or between Android and iOS).

import '../models/fat_models.dart';

enum ProductTypeConfidence {
  high, // multiple strong signals
  moderate, // one strong signal or several weak ones
  low, // ambiguous — defaulted to meat
}

class ProductTypeDetection {
  final ProductType productType;
  final ProductTypeConfidence confidence;
  final List<String> matchedKeywords;
  final bool isSiluriformes;

  const ProductTypeDetection({
    required this.productType,
    required this.confidence,
    required this.matchedKeywords,
    required this.isSiluriformes,
  });
}

class ProductTypeDetector {
  // Strong meat signals (3 points each) — mirrors iOS.
  static const List<String> _strongMeat = [
    'beef', 'steak', 'ground beef', 'chuck', 'sirloin',
    'ribeye', 'rib eye', 't-bone', 'tenderloin', 'brisket',
    'pork', 'pork chop', 'pork loin', 'bacon', 'ham',
    'chicken breast', 'chicken thigh', 'chicken wing',
    'turkey breast', 'ground turkey',
    'lamb chop', 'lamb shank', 'rack of lamb',
    'bison', 'venison', 'veal',
    'sausage', 'hot dog', 'hotdog', 'bratwurst', 'wiener', 'frankfurter',
    'bologna', 'salami', 'pepperoni', 'kielbasa', 'knockwurst',
    'liverwurst', 'mortadella', 'capicola', 'pastrami', 'corned beef',
    'deli meat', 'cold cut', 'luncheon meat', 'summer sausage',
    'usda prime', 'usda choice', 'usda select',
    'angus', 'wagyu', 'berkshire', 'duroc', 'heritage breed',
  ];

  // Strong seafood signals (3 points each) — iOS list plus the Android-added
  // species (yellowtail, monkfish, fish cake), kept as a strict superset.
  static const List<String> _strongSeafood = [
    'salmon', 'tuna', 'shrimp', 'prawns', 'lobster',
    'crab', 'scallop', 'oyster', 'mussel', 'clam',
    'cod', 'halibut', 'tilapia', 'mahi', 'swordfish',
    'snapper', 'grouper', 'trout', 'pollock', 'flounder',
    'sole', 'perch', 'walleye', 'sardine', 'anchovy',
    'mackerel', 'herring', 'squid', 'calamari', 'octopus',
    'sea bass', 'branzino', 'barramundi', 'arctic char',
    'rockfish', 'wahoo', 'pompano',
    'surimi', 'imitation crab',
    'wild caught', 'wild-caught',
    'farm raised', 'farm-raised',
    'msc certified', 'asc certified', 'bap certified',
    'marine stewardship', 'aquaculture stewardship',
    'seafood', 'fish fillet', 'fish stick',
    'fish cake', 'yellowtail', 'monkfish',
  ];

  // Weak meat signals (1 point each) — ambiguous, not reported as matches.
  static const List<String> _weakMeat = [
    'chicken', 'turkey', 'poultry', 'lamb',
    'roast', 'cutlet', 'chop', 'ground',
    'meat', 'meats', 'deli', 'cured', 'uncured', 'smoked', 'provisions',
  ];

  // Weak seafood signals. NOTE: bare "sea" was removed — it matched "sea
  // salt" (an ingredient on countless MEAT products) and mislabeled them
  // seafood. Generic packaging words ("net wt", "product of", "frozen",
  // "imported") and meat-capable cut words ("loin", "fillet") were also
  // removed — they appear on meat too and are not seafood signals.
  static const List<String> _weakSeafood = [
    'previously frozen',
    'stpp', 'phosphate',
    'ocean', 'atlantic', 'pacific',
    'gulf', 'alaskan', 'norwegian', 'sea salt-free',
  ];

  // FSIS-regulated Siluriformes species — the one seafood group that carries
  // a USDA establishment number instead of falling under FDA.
  static const List<String> _siluriformes = [
    'catfish', 'channel catfish', 'blue catfish', 'siluriformes',
    'ictalurus', 'pangasius', 'swai', 'basa', 'tra fish', 'striped pangasius',
  ];

  static bool isSiluriformes(String text) =>
      _siluriformes.any(text.toLowerCase().contains);

  static ProductTypeDetection detect(String scannedText) {
    final text = scannedText.toLowerCase();

    var meatScore = 0;
    var seafoodScore = 0;
    final matchedKeywords = <String>[];
    var siluriformesDetected = false;

    for (final k in _strongMeat) {
      if (text.contains(k)) {
        meatScore += 3;
        matchedKeywords.add(k);
      }
    }
    for (final k in _strongSeafood) {
      if (text.contains(k)) {
        seafoodScore += 3;
        matchedKeywords.add(k);
      }
    }
    for (final k in _siluriformes) {
      if (text.contains(k)) {
        seafoodScore += 3;
        siluriformesDetected = true;
        matchedKeywords.add(k);
      }
    }
    for (final k in _weakMeat) {
      if (text.contains(k)) meatScore += 1;
    }
    for (final k in _weakSeafood) {
      if (text.contains(k)) seafoodScore += 1;
    }

    // A USDA/FSIS inspection legend is a DEFINITIVE meat/poultry (or catfish)
    // signal: FDA-regulated seafood never carries a USDA inspection mark. So
    // when it's present and the product isn't catfish, weight meat strongly —
    // this is what rules out a hot dog being misread as seafood because of an
    // ingredient like "sea salt".
    final fsisMark = text.contains('inspected and passed') ||
        text.contains('u.s. inspected') ||
        text.contains('us inspected') ||
        text.contains('department of agriculture') ||
        text.contains('usda');
    if (fsisMark) {
      if (siluriformesDetected) {
        seafoodScore += 2;
      } else {
        meatScore += 3;
      }
    }

    // FDA registration number pattern suggests non-catfish seafood.
    if (RegExp(r'fda\s*(?:reg|registration|#)\s*\d+').hasMatch(text)) {
      seafoodScore += 3;
      matchedKeywords.add('FDA registration');
    }

    final ProductType productType;
    final ProductTypeConfidence confidence;

    // NOTE: ties at >= 3 route to seafood — this matches the shipped iOS
    // detector, whose first branch uses >= (its separate tie branch is
    // unreachable). Keep the two platforms behaviorally identical.
    if (seafoodScore >= meatScore && seafoodScore >= 3) {
      productType = ProductType.seafood;
      confidence = seafoodScore >= 6
          ? ProductTypeConfidence.high
          : ProductTypeConfidence.moderate;
    } else if (meatScore > seafoodScore && meatScore >= 3) {
      productType = ProductType.meat;
      confidence = meatScore >= 6
          ? ProductTypeConfidence.high
          : ProductTypeConfidence.moderate;
    } else {
      // No strong signals — default to meat.
      productType = ProductType.meat;
      confidence = ProductTypeConfidence.low;
    }

    return ProductTypeDetection(
      productType: productType,
      confidence: confidence,
      matchedKeywords: matchedKeywords,
      isSiluriformes: siluriformesDetected,
    );
  }
}
