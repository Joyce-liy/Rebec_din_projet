import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pharma/services/history_service.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  late AnimationController _animationController;
  
  List<Map<String, dynamic>> _detectedMeds = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Animation pour le trait de scan qui descend
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
      ResolutionPreset.max, // Qualité max pour l'OCR
      enableAudio: false,
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
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final XFile image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      List<Map<String, dynamic>> tempMeds = [];
      
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          String text = line.text.trim();
          // Filtrage intelligent
          if (text.length > 3 && !RegExp(r'[0-9]{2}/').hasMatch(text)) {
            tempMeds.add({"name": text, "selected": true});
          }
        }
      }

      setState(() {
        _detectedMeds = tempMeds;
        _isProcessing = false;
      });

      if (_detectedMeds.isNotEmpty) {
        _showResultsSheet(); // Affiche les résultats de façon élégante
      }
    } catch (e) {
      setState(() => _isProcessing = false);
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
          // APERÇU CAMÉRA PLEIN ÉCRAN
          if (_isInitialized) 
            CameraPreview(_controller!)
          else 
            const Center(child: CircularProgressIndicator(color: Colors.green)),

          // VISEUR ET OVERLAY
          _buildSmartOverlay(),

          // BOUTON RETOUR
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

          // BOUTON DE CAPTURE
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text("Alignez l'ordonnance dans le cadre", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _scanImage,
                  child: Container(
                    height: 80,
                    width: 80,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: _isProcessing 
                        ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Colors.green))
                        : const Icon(Icons.qr_code_scanner, size: 40, color: Colors.green),
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
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            // Fond semi-transparent avec trou au milieu (Viseur)
            ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
              child: Stack(
                children: [
                  Container(decoration: const BoxDecoration(color: Colors.black, backgroundBlendMode: BlendMode.dstOut)),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      height: 400,
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
            ),
            // Barre de scan animée
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                height: 400,
                child: Stack(
                  children: [
                    Positioned(
                      top: _animationController.value * 380,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                          gradient: const LinearGradient(colors: [Colors.transparent, Colors.green, Colors.transparent]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showResultsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              const Text("Médicaments identifiés", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Décochez ceux que vous ne cherchez pas", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _detectedMeds.length,
                  itemBuilder: (context, i) => CheckboxListTile(
                    activeColor: Colors.green,
                    title: Text(_detectedMeds[i]['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: _detectedMeds[i]['selected'],
                    onChanged: (val) => setSheetState(() => _detectedMeds[i]['selected'] = val),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    for (var med in _detectedMeds) {
                      if (med['selected']) HistoryService.instance.add(med['name'], source: "Scanner");
                    }
                    Navigator.pop(context); // Ferme le sheet
                    Navigator.pop(context); // Quitte le scanner
                  },
                  child: const Text("VÉRIFIER LE STOCK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}