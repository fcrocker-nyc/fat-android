import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../models/fat_models.dart';
import '../models/service_case_schema.dart';
import '../models/species_visual_classifier.dart';
import '../services/scan_store.dart';
import '../theme/fat_theme.dart';

/// Service-Case Seafood Capture flow. The venue gate runs first (the user picks
/// the establishment type), then a placard photo is OCR'd and parsed into a
/// [ServiceCaseRecord], which resolves to a tier + enforcement lanes. The
/// screen renders what the sign says with per-field confidence, and holds
/// species identity open — never confirming what the photo cannot prove.
class ServiceCaseCaptureScreen extends StatefulWidget {
  const ServiceCaseCaptureScreen({super.key});

  @override
  State<ServiceCaseCaptureScreen> createState() => _ServiceCaseCaptureScreenState();
}

class _ServiceCaseCaptureScreenState extends State<ServiceCaseCaptureScreen> {
  EstablishmentType _venue = EstablishmentType.coveredRetailer;
  ServiceCaseRecord? _record;
  bool _processing = false;
  String? _error;

  // Kept so the capture can be saved to History alongside its evaluation.
  String? _capturedImagePath;
  String _lastOcrText = '';
  bool _saving = false;
  bool _didSave = false;

  Future<void> _capture(ImageSource source) async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: source, imageQuality: 90);
      if (xFile == null) {
        setState(() => _processing = false);
        return;
      }
      final imgPath = await _persistImage(xFile.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(InputImage.fromFilePath(xFile.path));
      await recognizer.close();

      // Read the placard text (OCR) AND the whole fish itself (on-device visual pass), same frame.
      final visual = await SpeciesVisualClassifier.classify(xFile.path);
      final text = result.text;

      if (text.trim().isEmpty) {
        final rec = ServiceCaseParser.parse('', _venue);
        ServiceCaseParser.applyVisual(visual, rec);
        setState(() {
          _record = rec;
          _capturedImagePath = imgPath;
          _lastOcrText = '';
          _didSave = false;
          _processing = false;
          _error = visual == null
              ? 'No placard text and no whole fish detected. Frame the whole fish (not a fillet) and its sign, in good light.'
              : 'No placard text detected — showing the whole-fish visual read only.';
        });
        return;
      }
      final rec = ServiceCaseParser.parse(text, _venue);
      ServiceCaseParser.applyVisual(visual, rec);
      setState(() {
        _record = rec;
        _capturedImagePath = imgPath;
        _lastOcrText = text;
        _didSave = false;
        _processing = false;
      });
    } catch (e) {
      setState(() {
        _processing = false;
        _error = 'Error reading placard: $e';
      });
    }
  }

  /// Copy the picker temp file into the app's documents dir (scans/) so the
  /// History thumbnail survives after the OS clears the image cache. Same
  /// pattern as scan_screen. Returns the original path if the copy fails.
  Future<String> _persistImage(String tempPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final scans = Directory('${dir.path}/scans');
      if (!await scans.exists()) await scans.create(recursive: true);
      final ext = tempPath.contains('.') ? tempPath.split('.').last : 'jpg';
      final dest =
          '${scans.path}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(tempPath).copy(dest);
      return dest;
    } catch (_) {
      return tempPath;
    }
  }

  // ── Save to History ─────────────────────────────────────────────────────

  Future<void> _save(ServiceCaseRecord r) async {
    if (_saving || _didSave) return;
    setState(() => _saving = true);
    await ScanStore.instance.saveResult(_historyResult(r));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _didSave = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to scan history.')),
    );
  }

  /// Folds the service-case record into a [FATResult] so the capture lands in
  /// the same History stream as packaged-label scans (mirrors iOS). Only the
  /// fields a placard can actually disclose are populated; species identity
  /// stays partial/unverified — never confirmed from a photo.
  FATResult _historyResult(ServiceCaseRecord r) {
    DisclosureStatus status(ConfidenceState c) => switch (c) {
          ConfidenceState.known => DisclosureStatus.known,
          ConfidenceState.partial ||
          ConfidenceState.unverified => DisclosureStatus.partial,
          ConfidenceState.missing => DisclosureStatus.missing,
          ConfidenceState.notApplicable => DisclosureStatus.notRequired,
        };

    final cats = <SeafoodCategory, FATCategoryResult>{};

    final name = r.marketNameDisplayed;
    if (name != null) {
      var v = 'Sign says "$name" — species unverified';
      final acc = r.seafoodListMatch?.acceptableMarketName;
      if (acc != null) v += ' (Seafood List: $acc)';
      cats[SeafoodCategory.speciesIdentity] =
          FATCategoryResult(status: DisclosureStatus.partial, value: v);
    } else {
      cats[SeafoodCategory.speciesIdentity] = FATCategoryResult.missing;
    }

    cats[SeafoodCategory.countryOrigin] = FATCategoryResult(
      status: status(r.originConfidence),
      value: r.countryOfOrigin.isEmpty ? null : r.countryOfOrigin.join(', '),
    );

    cats[SeafoodCategory.productionMethodFeed] = FATCategoryResult(
      status: status(r.methodConfidence),
      value: r.methodOfProduction == null
          ? null
          : r.methodOfProduction!.raw[0] +
              r.methodOfProduction!.raw.substring(1).toLowerCase(),
    );

    if (r.fsisEstablishmentNumber != null) {
      cats[SeafoodCategory.processor] = FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'FSIS ${r.fsisEstablishmentNumber}');
    } else if (r.shellfishCertNumber != null) {
      cats[SeafoodCategory.processor] = FATCategoryResult(
          status: DisclosureStatus.known,
          value: 'Shellfish cert ${r.shellfishCertNumber}');
    }

    if (r.previouslyFrozen != PreviouslyFrozen.unknown) {
      cats[SeafoodCategory.qualityHandling] = FATCategoryResult(
        status: DisclosureStatus.known,
        value: r.previouslyFrozen == PreviouslyFrozen.labeledPreviouslyFrozen
            ? 'Labeled previously frozen'
            : 'Presented fresh',
      );
    }

    final method = switch (r.methodOfProduction) {
      MethodOfProduction.wild => SeafoodProductionMethod.wildCaught,
      MethodOfProduction.farmed => SeafoodProductionMethod.farmRaised,
      _ => null,
    };

    return FATResult(
      scannedText: _historySummary(r),
      categories: const {},
      productType: ProductType.seafood,
      seafoodCategories: cats,
      isSiluriformes: r.categoryLane == CategoryLane.fsisSiluriformes,
      productionMethod: method,
      imagePaths: _capturedImagePath == null ? const [] : [_capturedImagePath!],
    );
  }

  /// Human-readable record of the capture — searchable in History and shown
  /// as the scanned text on the saved evaluation.
  String _historySummary(ServiceCaseRecord r) {
    final lines = <String>[
      'FAT Service-Case Capture (loose seafood at a counter)',
      'Venue: ${r.establishmentType.display}',
    ];
    if (r.marketNameDisplayed != null) {
      lines.add('Market name displayed: ${r.marketNameDisplayed}');
    }
    final match = r.seafoodListMatch?.acceptableMarketName;
    if (match != null) lines.add('Seafood List name: $match');
    if (r.countryOfOrigin.isNotEmpty) {
      lines.add('Country of origin: ${r.countryOfOrigin.join(', ')}');
    }
    if (r.methodOfProduction != null) {
      lines.add('Method of production: ${r.methodOfProduction!.raw}');
    }
    lines.add('Species identity: held open (a photo cannot confirm species)');
    if (r.visualObservation != null) {
      lines.add('Whole-fish visual read: ${r.visualObservation}');
    }
    if (r.visualCrossCheck != null) {
      lines.add('Sign vs. camera: ${r.visualVerdict}');
    }
    if (r.shellfishCertNumber != null) {
      lines.add('Shellfish cert: ${r.shellfishCertNumber}');
    }
    if (r.fsisEstablishmentNumber != null) {
      lines.add('FSIS establishment: ${r.fsisEstablishmentNumber}');
    }
    if (r.pricePerLb != null) {
      lines.add('Price: \$${r.pricePerLb!.toStringAsFixed(2)}/lb');
    }
    if (r.substitutionRiskBand != null) {
      lines.add('Substitution risk: ${r.substitutionRiskBand}');
    }
    lines.add('Resolves to: ${r.resolve().raw}');
    final lanes = r.enforcementLanes();
    lines.add(
        'Enforcement lanes: ${lanes.isEmpty ? "none" : lanes.join(" · ")}');
    if (_lastOcrText.isNotEmpty) {
      lines.add('');
      lines.add('Placard text as read:');
      lines.add(_lastOcrText);
    }
    return lines.join('\n');
  }

  Color _chipColor(ConfidenceState s) => switch (s) {
        ConfidenceState.known => FATTheme.successGreen,
        ConfidenceState.partial => FATTheme.fatAmber,
        ConfidenceState.unverified => FATTheme.fatRed,
        ConfidenceState.missing => FATTheme.textSecondary,
        ConfidenceState.notApplicable => FATTheme.usdaApprovedBlue,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Service-Case Capture'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Loose seafood at the counter has no package to scan — only a USDA AMS placard. Pick the venue, photograph the placard, and FAT reads what the sign discloses.',
                style: TextStyle(fontSize: 15, height: 1.3),
              ),
              const SizedBox(height: 18),

              // ── Gate: venue selector ──
              const Text('1. Where are you?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text(
                'The venue gate runs first: it decides whether a missing origin placard is a compliance finding or a non-event.',
                style: TextStyle(fontSize: 13, color: FATTheme.textSecondary, height: 1.3),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EstablishmentType.values
                    .where((e) => e != EstablishmentType.unknown)
                    .map((e) => ChoiceChip(
                          label: Text(e.display),
                          selected: _venue == e,
                          selectedColor: FATTheme.scanGreen,
                          labelStyle: TextStyle(
                            color: _venue == e ? Colors.white : Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          backgroundColor: FATTheme.primaryGreen,
                          onSelected: (_) => setState(() {
                            _venue = e;
                            if (_record != null) {
                              _record = ServiceCaseRecord(
                                establishmentType: e,
                                processedValueAdded: _record!.processedValueAdded,
                                categoryLane: _record!.categoryLane,
                                countryOfOrigin: _record!.countryOfOrigin,
                                originLegible: _record!.originLegible,
                                methodOfProduction: _record!.methodOfProduction,
                                methodLegible: _record!.methodLegible,
                                marketNameDisplayed: _record!.marketNameDisplayed,
                                seafoodListMatch: _record!.seafoodListMatch,
                                substitutionRiskBand: _record!.substitutionRiskBand,
                                productForm: _record!.productForm,
                                shellfishCertNumber: _record!.shellfishCertNumber,
                                fsisEstablishmentNumber: _record!.fsisEstablishmentNumber,
                                previouslyFrozen: _record!.previouslyFrozen,
                                pricePerLb: _record!.pricePerLb,
                              );
                            }
                          }),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 22),

              // ── Capture ──
              const Text('2. Photograph the placard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              if (_processing) ...[
                const Center(child: CircularProgressIndicator(color: FATTheme.scanGreen)),
                const SizedBox(height: 12),
                const Center(
                    child: Text('Reading placard…',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () => _capture(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 24),
                  label: const Text('Capture Placard',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FATTheme.scanGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(58),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _capture(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Choose from library'),
                  style: TextButton.styleFrom(foregroundColor: FATTheme.scanGreen),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FATTheme.errorBGTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: FATTheme.errorRed),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: FATTheme.errorRed))),
                  ]),
                ),
              ],

              if (_record != null) ...[
                const SizedBox(height: 24),
                _result(_record!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Result ──

  Widget _result(ServiceCaseRecord r) {
    final tier = r.resolve();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('What the sign discloses',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        _card([
          _fieldRow('Market name', r.marketNameDisplayed ?? '—', ConfidenceState.known),
          _fieldRow('Country of origin',
              r.countryOfOrigin.isEmpty ? '—' : r.countryOfOrigin.join(', '), r.originConfidence),
          _fieldRow('Method of production',
              r.methodOfProduction?.raw ?? '—', r.methodConfidence),
          _fieldRow('Seafood List name',
              r.seafoodListMatch?.acceptableMarketName ?? '—',
              r.seafoodListMatch?.confidence ?? ConfidenceState.missing),
          _fieldRow('Species identity', 'held open', r.speciesIdentityConfidence),
          _fieldRow(
            'Whole-fish visual read',
            r.visualObservation == null
                ? 'no whole fish detected'
                : (r.visualConfidence == null
                    ? r.visualObservation!
                    : '${r.visualObservation} (${(r.visualConfidence! * 100).round()}%)'),
            ConfidenceState.unverified,
          ),
          if (r.visualCrossCheck != null) _plainRow('Sign vs. camera', r.visualVerdict),
          if (r.shellfishCertNumber != null)
            _fieldRow('Shellfish cert', r.shellfishCertNumber!, ConfidenceState.known),
          if (r.previouslyFrozen != PreviouslyFrozen.unknown)
            _plainRow('Previously frozen',
                r.previouslyFrozen == PreviouslyFrozen.labeledPreviouslyFrozen
                    ? 'labeled' : 'presented fresh'),
          if (r.pricePerLb != null)
            _plainRow('Price', '\$${r.pricePerLb!.toStringAsFixed(2)}/lb'),
        ]),
        const SizedBox(height: 14),

        // Resolution
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FATTheme.scanGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FATTheme.scanGreen.withValues(alpha: 0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Resolves to  ',
                  style: TextStyle(fontSize: 14, color: FATTheme.textSecondary)),
              Text(tier.raw,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: FATTheme.scanGreen)),
            ]),
            const SizedBox(height: 6),
            Text('Enforcement lanes: ${r.enforcementLanes().isEmpty ? "none" : r.enforcementLanes().join(" · ")}',
                style: const TextStyle(fontSize: 13)),
            if (tier == ResolutionTier.notApplicable) ...[
              const SizedBox(height: 6),
              const Text(
                  'This venue (or a processed item) is exempt from COOL, so a missing origin placard is not a compliance finding.',
                  style: TextStyle(fontSize: 13, height: 1.3)),
            ],
          ]),
        ),

        // Substitution advisory
        if (r.substitutionRiskBand != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FATTheme.fatAmber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FATTheme.fatAmber.withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: FATTheme.fatAmber, size: 18),
                const SizedBox(width: 6),
                Text('Substitution risk: ${r.substitutionRiskBand}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 4),
              const Text(
                  'The displayed name is reported as displayed; species stays unverified. We never confirm "this is Atlantic salmon" as fact from a photo. Of 120 nationwide "red snapper" samples DNA-tested by Oceana, only 7 actually were.',
                  style: TextStyle(fontSize: 13, height: 1.3)),
            ]),
          ),
        ],

        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: (_saving || _didSave) ? null : () => _save(r),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.black))
              : Icon(_didSave ? Icons.check_circle : Icons.archive_outlined,
                  size: 20, color: Colors.black),
          label: Text(
              _didSave ? 'Saved to History' : (_saving ? 'Saving…' : 'Save to History'),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black)),
          style: ElevatedButton.styleFrom(
            backgroundColor: FATTheme.scanGreen,
            disabledBackgroundColor: FATTheme.scanGreen.withValues(alpha: 0.5),
            minimumSize: const Size.fromHeight(54),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _capture(ImageSource.camera),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Capture another'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FATTheme.scanGreen,
            side: const BorderSide(color: FATTheme.scanGreen),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }

  Widget _card(List<Widget> rows) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FATTheme.primaryGreen.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 14, color: Color(0x22000000)),
              rows[i],
            ],
          ],
        ),
      );

  Widget _fieldRow(String label, String value, ConfidenceState state) => Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: const TextStyle(fontSize: 13, color: FATTheme.textSecondary)),
          ),
          Expanded(
            flex: 5,
            child: Text(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 8),
          _chip(state),
        ],
      );

  Widget _plainRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: const TextStyle(fontSize: 13, color: FATTheme.textSecondary)),
          ),
          const SizedBox(width: 8),
          // Expanded, not bare Text: a long value (the sign-vs-camera verdict)
          // overflowed the row and crushed the label to one letter per line.
          Expanded(
            flex: 7,
            child: Text(value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                textAlign: TextAlign.right),
          ),
        ],
      );

  Widget _chip(ConfidenceState state) {
    final c = _chipColor(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(state.label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w900, color: c, fontFamily: 'monospace')),
    );
  }
}
