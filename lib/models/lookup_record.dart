import 'package:flutter/material.dart';

/// The four lookup surfaces, mirroring the Lookup tab (and iOS LookupCategory).
enum LookupCategory {
  establishment, // EST
  meatBrand, // Meat Brand
  seafoodBrand, // Seafood Brand
  seafoodFDA; // Seafood FDA

  /// Short label used on the History category filter (matches the Lookup tabs).
  String get shortName {
    switch (this) {
      case LookupCategory.establishment: return 'EST';
      case LookupCategory.meatBrand:     return 'Meat Brand';
      case LookupCategory.seafoodBrand:  return 'Seafood Brand';
      case LookupCategory.seafoodFDA:    return 'Seafood FDA';
    }
  }

  IconData get icon {
    switch (this) {
      case LookupCategory.establishment: return Icons.tag;
      case LookupCategory.meatBrand:     return Icons.apartment;
      case LookupCategory.seafoodBrand:  return Icons.set_meal;
      case LookupCategory.seafoodFDA:    return Icons.report;
    }
  }
}

/// A single lookup event recorded to History. Unlike a scan record (which
/// carries label images + a full disclosure evaluation), a lookup record is a
/// lightweight snapshot of a search the user ran on the Lookup tab.
class LookupRecord {
  final String id;
  final DateTime date;
  final LookupCategory category;

  /// The raw text the user searched for.
  final String query;

  /// Primary result line — brand / processor / entity name, or a
  /// "not found" message when the search returned nothing.
  final String resultTitle;

  /// Optional secondary line — corporate parent, EST # + location, country.
  final String? resultSubtitle;

  /// Number of results the search returned (0 = miss).
  final int matchCount;

  /// True when the top result carries something worth surfacing: foreign
  /// ownership, an FDA import alert / enforcement history, or FSIS concerns.
  final bool flagged;

  const LookupRecord({
    required this.id,
    required this.date,
    required this.category,
    required this.query,
    required this.resultTitle,
    this.resultSubtitle,
    required this.matchCount,
    this.flagged = false,
  });

  bool get hasResults => matchCount > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date.toIso8601String(),
        'category': category.name,
        'query': query,
        'resultTitle': resultTitle,
        'resultSubtitle': resultSubtitle,
        'matchCount': matchCount,
        'flagged': flagged,
      };

  static LookupRecord fromMap(Map<String, dynamic> m) {
    final catName = m['category'] as String? ?? 'establishment';
    final category = LookupCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => LookupCategory.establishment,
    );
    return LookupRecord(
      id: m['id'] as String? ?? '',
      date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
      category: category,
      query: m['query'] as String? ?? '',
      resultTitle: m['resultTitle'] as String? ?? '',
      resultSubtitle: m['resultSubtitle'] as String?,
      matchCount: (m['matchCount'] as num?)?.toInt() ?? 0,
      flagged: m['flagged'] as bool? ?? false,
    );
  }
}
