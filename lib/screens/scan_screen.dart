import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/fat_models.dart';
import '../interpreter/foreign_establishment.dart';
import '../interpreter/label_interpreter.dart';
import '../interpreter/prepared_food.dart';
import '../interpreter/product_type_detector.dart';
import '../interpreter/seafood_interpreter.dart';
import '../menu/menu_screens.dart';
import '../theme/fat_theme.dart';
import '../services/lost_photo_recovery.dart';
import '../services/scan_store.dart';
import 'results_screen.dart';
import 'seafood_results_screen.dart';
import 'service_case_capture_screen.dart';

/// Every camera-based scan the app offers. The Scan tab lists all of them;
/// keep in step with the iOS `ScanOption` in ScanView.swift.
enum ScanOption {
  label(
    'Scan Label',
    'Point at the label on packaged meat, poultry, seafood or prepared food. '
        'Add more panels if needed, then see what the label discloses.',
    Icons.camera_alt_outlined,
  ),
  looseSeafood(
    'Loose Seafood at a Counter',
    'Point at the sign on a full-service seafood case. See the country of '
        'origin and whether the fish is wild or farmed.',
    Icons.storefront_outlined,
  ),
  menu(
    'Restaurant Menu',
    'Point at a restaurant menu. See what claims like grass-fed or '
        'wild-caught mean, plus questions to ask your server.',
    Icons.restaurant_menu,
  );

  const ScanOption(this.title, this.description, this.icon);
  final String title;
  final String description;
  final IconData icon;
}

class ScanScreen extends StatefulWidget {
  final bool autoLaunch;
  final VoidCallback onAutoLaunchConsumed;
  // A label photo recovered after Android restarted the app mid-capture
  // (LostPhotoRecovery); scanned as if it had just come back from the camera.
  final String? recoveredPhotoPath;
  final VoidCallback? onRecoveredPhotoConsumed;

  const ScanScreen({
    super.key,
    required this.autoLaunch,
    required this.onAutoLaunchConsumed,
    this.recoveredPhotoPath,
    this.onRecoveredPhotoConsumed,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  // "Found the EST — add another scan" flow: the results screen pops back with
  // a sentinel; the previous evaluation's text and photos are kept as the base,
  // the camera reopens for the extra panel, and the combined re-evaluation is
  // marked Revised.
  String _pendingBaseText = '';
  List<String> _pendingBasePaths = const [];

  @override
  void didUpdateWidget(ScanScreen old) {
    super.didUpdateWidget(old);
    if (widget.autoLaunch && !old.autoLaunch) {
      widget.onAutoLaunchConsumed();
      _launchCamera();
    }
    if (widget.recoveredPhotoPath != null && old.recoveredPhotoPath == null) {
      // Post-frame: consuming it calls the parent's setState, not allowed
      // mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scanRecovered());
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAutoLaunchConsumed();
        _launchCamera();
      });
    }
    if (widget.recoveredPhotoPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scanRecovered());
    }
  }

  void _scanRecovered() {
    final path = widget.recoveredPhotoPath;
    if (path == null || !mounted) return;
    widget.onRecoveredPhotoConsumed?.call();
    _pickAndScan(ImageSource.camera, recoveredPath: path);
  }

  Future<void> _launchCamera() async {
    await _pickAndScan(ImageSource.camera);
  }

  Future<void> _pickAndScan(ImageSource source, {String? recoveredPath}) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final xFile = recoveredPath != null
          ? XFile(recoveredPath)
          : await LostPhotoRecovery.pickImage(PhotoScan.label, source: source);
      if (xFile == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(xFile.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();

      final newText = result.text;
      if (newText.trim().isEmpty) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'No text detected. Try again with better lighting.';
        });
        return;
      }

      // Copy the photo out of the picker's temp cache into app documents so it
      // survives to History (falls back to the temp path if the copy fails).
      final imgPath = await _persistImage(xFile.path);

      // Revision: combine the kept base evaluation's text/photos with the new
      // panel so the re-evaluation sees everything, including the found EST.
      final isRevision = _pendingBaseText.isNotEmpty;
      final scannedText =
          isRevision ? '$_pendingBaseText\n$newText' : newText;
      final imagePaths = [..._pendingBasePaths, imgPath];
      _pendingBaseText = '';
      _pendingBasePaths = const [];

      // Route by product type: seafood labels go to the seafood pipeline,
      // everything else to the meat pipeline.
      final detection = ProductTypeDetector.detect(scannedText);
      final bool isSeafood = detection.productType == ProductType.seafood;
      final FATResult fatResult;
      if (isSeafood) {
        final si = SeafoodInterpreter.interpret(scannedText);
        fatResult = FATResult(
          scannedText: scannedText,
          categories: const {},
          productType: ProductType.seafood,
          seafoodCategories: si.categories,
          isSiluriformes: si.isSiluriformes,
          productionMethod: si.productionMethod,
          productionSystem: si.productionSystem,
          detectedEstablishmentNumber: si.detectedEstablishmentNumber,
          isRevised: isRevision,
          imagePaths: imagePaths,
        );
      } else {
        var categories = LabelInterpreter.interpret(scannedText);
        final estNumber = LabelInterpreter.extractEstablishmentNumber(
          scannedText.toLowerCase(),
        );
        // Prepared / Multi-Ingredient lane: a stew, pizza, or soup is not a
        // single-animal product — per-animal categories go `.notRequired`,
        // Species becomes a multi-species list, and an FDA-jurisdiction
        // product (below the FSIS meat-content thresholds) legally carries no
        // USDA legend or EST, so the red missing-EST banner must not fire.
        final prepared = PreparedFoodDetector.detect(scannedText);
        final preparedFsis = prepared.isPrepared &&
            (estNumber != null ||
                PreparedFoodDetector.hasFsisLegend(scannedText));
        if (prepared.isPrepared) {
          categories = PreparedFoodDetector.apply(
            categories,
            prepared,
            fsisJurisdiction: preparedFsis,
          );
        }
        final isMeat =
            categories[FATCategory.species]?.status == DisclosureStatus.known;
        // USDA retail-store exemption (9 CFR 303.1(d)): a store-cut/ground item
        // legitimately carries no establishment number, so it is NOT a compliance
        // concern — estMissing stays false when the exemption applies.
        // Imported product: the label carries the producing country's
        // establishment mark (e.g. "IT 1937 L CE") instead of a USDA
        // establishment number. Only consult it when no domestic EST was read,
        // so a US label that merely mentions a country is unaffected.
        final foreign = estNumber == null
            ? ForeignEstablishmentDetector.detect(scannedText)
            : null;
        if (foreign != null) {
          // The mark DOES disclose the producing establishment — credit the
          // Processor category and say plainly that FAT's domestic lookup
          // cannot resolve a foreign number.
          categories[FATCategory.processor] = FATCategoryResult(
            status: DisclosureStatus.known,
            value: 'Foreign establishment ${foreign.display} '
                '(${foreign.countryName})',
            credibilityNote: ForeignEstablishmentDetector.processorNote(foreign),
          );
          // An establishment mark names the country the product was produced
          // or packed in — not necessarily where the animal was raised — so it
          // is partial origin information, not a "Product of" origin claim.
          if (categories[FATCategory.countryOrigin]?.status ==
              DisclosureStatus.missing) {
            categories[FATCategory.countryOrigin] = FATCategoryResult(
              status: DisclosureStatus.partial,
              value: 'Establishment mark indicates ${foreign.countryName}',
              credibilityNote:
                  'Taken from the inspection mark, which identifies the country '
                  'of the approved establishment that produced or packed the '
                  'product. It is not a country-of-origin claim and does not '
                  'state where the animal was raised or slaughtered.',
            );
          }
        }
        final exemption = LabelInterpreter.detectRetailExemption(scannedText);
        // OCR-misread guard: a known poultry-only EST on a red-meat label (or
        // vice versa) flags the card instead of reporting the wrong plant.
        final mismatch = LabelInterpreter.checkEstSpeciesMismatch(
          estNumber: estNumber,
          speciesResult: categories[FATCategory.species],
        );
        fatResult = FATResult(
          scannedText: scannedText,
          categories: categories,
          detectedEstablishmentNumber: estNumber,
          // An imported product legally carries no USDA establishment number —
          // flagging its absence would be a false compliance accusation.
          estMissing: isMeat &&
              estNumber == null &&
              !exemption.isExempt &&
              !prepared.isPrepared &&
              foreign == null,
          retailExempt: exemption.isExempt,
          retailExemptStoreName: exemption.storeName,
          estSpeciesMismatch: mismatch.$1,
          estSpeciesMismatchNote: mismatch.$2,
          foreignEstablishment: foreign?.display,
          foreignEstablishmentToken: foreign?.token,
          foreignCountry: foreign?.countryName,
          foreignLookupKeys: foreign?.lookupKeys ?? const [],
          isPreparedFood: prepared.isPrepared,
          preparedFsisJurisdiction: preparedFsis,
          isRevised: isRevision,
          imagePaths: imagePaths,
        );
      }

      await ScanStore.instance.saveResult(fatResult);

      if (!mounted) return;
      final ret = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => isSeafood
              ? SeafoodResultsScreen(result: fatResult)
              : ResultsScreen(result: fatResult, canAddScan: true),
        ),
      );
      // The missing-EST card's "add another scan" link: keep this evaluation
      // as the base and reopen the camera for the panel carrying the EST.
      if (ret == 'fat_add_scan' && mounted) {
        _pendingBaseText = fatResult.scannedText;
        _pendingBasePaths = fatResult.imagePaths;
        await _pickAndScan(ImageSource.camera);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error processing image: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Copy a picker temp file into the app's documents dir (scans/) so the
  /// thumbnail survives after the OS clears the image cache. Returns the new
  /// path, or the original temp path if the copy fails (still works in-session).
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

  Widget _optionRow(ScanOption option, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: FATTheme.primaryGreen,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: Key('scanOption.${option.name}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(option.icon, color: FATTheme.scanGreen, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.description,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.chevron_right, color: FATTheme.scanGreen),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Scan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Choose what you are pointing the camera at.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  height: 1.18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (_isProcessing) ...[
                const Center(
                  child: CircularProgressIndicator(color: FATTheme.scanGreen),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Analyzing label…',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ] else ...[
                // PRIMARY — packaged label scan (meat, poultry, seafood,
                // prepared food; auto-routed after OCR).
                ElevatedButton.icon(
                  key: Key('scanOption.${ScanOption.label.name}'),
                  onPressed: _launchCamera,
                  icon: Icon(ScanOption.label.icon, size: 26),
                  label: Text(
                    ScanOption.label.title,
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FATTheme.scanGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(66),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ScanOption.label.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, height: 1.3, color: Colors.black),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // SECONDARY — every other camera-based scan in the app, reusing
              // the same entries Home uses.
              const SizedBox(height: 24),
              const Text(
                'Other scans',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _optionRow(
                ScanOption.looseSeafood,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServiceCaseCaptureScreen(),
                  ),
                ),
              ),
              _optionRow(
                ScanOption.menu,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MenuScanScreen()),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
