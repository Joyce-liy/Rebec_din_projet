import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pharma/services/gemini_service.dart';
import 'package:pharma/services/history_service.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;

  // TextRecognizer gardé pour usage futur éventuel
  final TextRecognizer _textRecognizer = TextRecognizer();
  late AnimationController _animationController;

  List<Map<String, dynamic>> _detectedMeds = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint("Erreur caméra: $e");
    }
  }

  Future<void> _scanImage() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final XFile image = await _controller!.takePicture();
      final bytes = await image.readAsBytes();

      // ✅ Appel corrigé — méthode présente dans GeminiService
      final List<String> result =
          await GeminiService.readHandwrittenPrescription(bytes);

      if (!mounted) return;

      setState(() {
        _detectedMeds = result
            .map((name) => {"name": name, "selected": true})
            .toList();
        _isProcessing = false;
      });

      if (_detectedMeds.isNotEmpty) {
        _showResultsSheet();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Aucun médicament détecté. Essayez de mieux éclairer l'image."),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized)
            CameraPreview(_controller!)
          else
            const Center(
                child: CircularProgressIndicator(color: Colors.green)),

          _buildSmartOverlay(),

          // Bouton Fermer
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black26,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Interface de capture
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "Alignez l'ordonnance dans le cadre",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _scanImage,
                  child: Container(
                    height: 85,
                    width: 85,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: _isProcessing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  color: Colors.green, strokeWidth: 3),
                            )
                          : const Icon(Icons.qr_code_scanner,
                              size: 40, color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartOverlay() {
    double width = MediaQuery.of(context).size.width * 0.85;
    double height = 400;

    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5), BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                  decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut)),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.green.withOpacity(0.5), width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Positioned(
                      top: _animationController.value * (height - 20),
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                                color: Colors.green.withOpacity(0.6),
                                blurRadius: 10,
                                spreadRadius: 2)
                          ],
                          gradient: const LinearGradient(colors: [
                            Colors.transparent,
                            Colors.green,
                            Colors.transparent
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showResultsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              const Text("Médicaments identifiés",
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Désélectionnez si nécessaire",
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _detectedMeds.length,
                  itemBuilder: (context, i) => CheckboxListTile(
                    activeColor: Colors.green,
                    title: Text(_detectedMeds[i]['name'],
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: _detectedMeds[i]['selected'],
                    onChanged: (val) =>
                        setSheetState(() => _detectedMeds[i]['selected'] = val),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () {
                    final selectedMedications = _detectedMeds
                        .where((med) => med['selected'] == true)
                        .map((med) => med['name'] as String)
                        .toList();

                    for (var medName in selectedMedications) {
                      HistoryService.instance.add(medName, source: "Scanner IA");
                    }

                    Navigator.pop(context);
                    Navigator.pop(context, selectedMedications);
                  },
                  child: const Text("RECHERCHER",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}