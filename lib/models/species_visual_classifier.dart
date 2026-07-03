// On-device visual read of a WHOLE fish (Google ML Kit image labeling — nothing leaves the phone).
//
// HONEST SCOPE: ML Kit's base labeler is coarse. For a whole animal or shellfish it can often name
// the broad type (fish / crab / shrimp / squid / oyster); it is NOT a species ID and NOT DNA. Cuts
// and fillets are deliberately flagged, not scored — the visual read applies to WHOLE fish only.

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import 'service_case_schema.dart';

class SpeciesVisualClassifier {
  // [labelSubstring, broadType, fineTag, display]. First (highest-confidence) seafood hit wins;
  // specific entries precede the generic "seafood"/"fish" catch-alls.
  static const List<List<dynamic>> _map = [
    // Whole-fish morphology
    ['salmon', 'finfish', 'salmon', 'salmon'],
    ['trout', 'finfish', 'salmon', 'trout'],
    ['tuna', 'finfish', null, 'tuna-like fish'],
    ['mackerel', 'finfish', null, 'mackerel'],
    ['sardine', 'finfish', null, 'sardine'],
    ['herring', 'finfish', null, 'herring'],
    ['anchovy', 'finfish', null, 'anchovy'],
    ['snapper', 'finfish', null, 'snapper-shaped fish'],
    ['grouper', 'finfish', null, 'grouper-shaped fish'],
    ['catfish', 'finfish', null, 'catfish-shaped fish'],
    ['carp', 'finfish', null, 'carp-like fish'],
    ['goldfish', 'finfish', null, 'small whole fish'],
    ['koi', 'finfish', null, 'carp-like fish'],
    ['tilapia', 'finfish', null, 'tilapia-shaped fish'],
    ['perch', 'finfish', null, 'perch-shaped fish'],
    ['mullet', 'finfish', null, 'mullet-shaped fish'],
    ['barracuda', 'finfish', null, 'barracuda-shaped fish'],
    ['mahi', 'finfish', null, 'mahi-shaped fish'],
    ['swordfish', 'finfish', null, 'billfish'],
    ['halibut', 'finfish', null, 'flatfish'],
    ['sturgeon', 'finfish', null, 'sturgeon-shaped fish'],
    ['pufferfish', 'finfish', null, 'pufferfish'],
    ['shark', 'finfish', null, 'shark/ray'],
    ['ray', 'finfish', null, 'shark/ray'],
    ['eel', 'finfish', null, 'eel'],
    ['flatfish', 'finfish', null, 'flatfish'],
    ['cod', 'finfish', null, 'cod-shaped fish'],
    ['bass', 'finfish', null, 'bass-shaped fish'],
    // Cuts / parts — whole fish only; flagged, never scored
    ['sashimi', 'cut', null, 'a cut or slice, not a whole fish'],
    ['sushi', 'cut', null, 'a cut or slice, not a whole fish'],
    ['fillet', 'cut', null, 'a fillet, not a whole fish'],
    ['steak', 'cut', null, 'a steak/portion, not a whole fish'],
    // Shellfish
    ['crab', 'crab', 'crab', 'crab'],
    ['lobster', 'lobster', 'lobster', 'lobster'],
    ['shrimp', 'shrimp', 'shrimp', 'shrimp'],
    ['prawn', 'shrimp', 'shrimp', 'prawn'],
    ['crayfish', 'shrimp', null, 'crayfish'],
    ['squid', 'cephalopod', null, 'squid'],
    ['octopus', 'cephalopod', null, 'octopus'],
    ['cuttlefish', 'cephalopod', null, 'cuttlefish'],
    ['oyster', 'mollusk', null, 'oyster'],
    ['clam', 'mollusk', null, 'clam'],
    ['mussel', 'mollusk', null, 'mussel'],
    ['scallop', 'mollusk', null, 'scallop'],
    ['shellfish', 'mollusk', null, 'shellfish'],
    // Generic catch-alls
    ['seafood', 'finfish', null, 'seafood'],
    ['fish', 'finfish', null, 'fish'],
  ];

  static Future<VisualRead?> classify(String imagePath) async {
    final labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.10));
    try {
      final labels = await labeler.processImage(InputImage.fromFilePath(imagePath));
      labels.sort((a, b) => b.confidence.compareTo(a.confidence));
      for (final l in labels) {
        final id = l.label.toLowerCase();
        for (final m in _map) {
          if (id.contains(m[0] as String)) {
            return VisualRead(m[3] as String, m[1] as String, m[2] as String?, l.confidence);
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      await labeler.close();
    }
  }
}
