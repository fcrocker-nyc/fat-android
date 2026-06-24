import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/fat_models.dart';
import '../interpreter/label_interpreter.dart';
import '../interpreter/seafood_interpreter.dart';
import '../theme/fat_theme.dart';
import '../services/scan_store.dart';
import 'results_screen.dart';
import 'seafood_results_screen.dart';
import 'service_case_capture_screen.dart';

class ScanScreen extends StatefulWidget {
  final bool autoLaunch;
  final VoidCallback onAutoLaunchConsumed;

  const ScanScreen({
    super.key,
    required this.autoLaunch,
    required this.onAutoLaunchConsumed,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void didUpdateWidget(ScanScreen old) {
    super.didUpdateWidget(old);
    if (widget.autoLaunch && !old.autoLaunch) {
      widget.onAutoLaunchConsumed();
      _launchCamera();
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
  }

  Future<void> _launchCamera() async {
    await _pickAndScan(ImageSource.camera);
  }

  Future<void> _pickAndScan(ImageSource source) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: source, imageQuality: 90);
      if (xFile == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(xFile.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();

      final scannedText = result.text;
      if (scannedText.trim().isEmpty) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'No text detected. Try again with better lighting.';
        });
        return;
      }

      // Route by product type: seafood labels go to the seafood pipeline,
      // everything else to the meat pipeline.
      final bool isSeafood = SeafoodInterpreter.isSeafood(scannedText);
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
          detectedEstablishmentNumber: si.detectedEstablishmentNumber,
        );
      } else {
        final categories = LabelInterpreter.interpret(scannedText);
        final estNumber = LabelInterpreter.extractEstablishmentNumber(
          scannedText.toLowerCase(),
        );
        final isMeat =
            categories[FATCategory.species]?.status == DisclosureStatus.known;
        fatResult = FATResult(
          scannedText: scannedText,
          categories: categories,
          detectedEstablishmentNumber: estNumber,
          estMissing: isMeat && estNumber == null,
        );
      }

      await ScanStore.instance.saveResult(fatResult);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => isSeafood
              ? SeafoodResultsScreen(result: fatResult)
              : ResultsScreen(result: fatResult),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Error processing image: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
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
                'Photograph one or more label panels, then evaluate what the label discloses.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  height: 1.18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 34),
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
                ElevatedButton.icon(
                  onPressed: _launchCamera,
                  icon: const Icon(Icons.camera_alt_outlined, size: 26),
                  label: const Text(
                    'Scan Label',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FATTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(66),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ServiceCaseCaptureScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_outlined, size: 20),
                  label: const Text(
                    'Loose seafood at a counter?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FATTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
