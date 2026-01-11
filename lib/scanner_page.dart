import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pharma/services/history_service.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  // Liste dynamique des médicaments détectés
  List<Map<String, dynamic>> _detectedMeds = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // Initialisation de la caméra
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[0], 
      ResolutionPreset.high, 
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

  // Fonction de Scan et OCR (Reconnaissance de texte)
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
          
          // Filtrage basique : on ignore les dates et les textes trop courts
          if (text.length > 3 && !text.contains('/') && !text.contains('202')) {
            tempMeds.add({
              "name": text,
              "selected": true, // Sélectionné par défaut comme sur l'image
            });
          }
        }
      }

      setState(() {
        _detectedMeds = tempMeds;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint("Erreur scan: $e");
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Scan d'ordonnance", style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          // ZONE CAMÉRA
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isInitialized) 
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CameraPreview(_controller!),
                  )
                else 
                  const Center(child: CircularProgressIndicator()),
                
                // L'Overlay bleu (Cadre de scan)
                _buildScanOverlay(),

                // Bouton de capture
                Positioned(
                  bottom: 20,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    onPressed: _scanImage,
                    child: _isProcessing 
                      ? const CircularProgressIndicator() 
                      : const Icon(Icons.camera_alt, color: Colors.blue, size: 30),
                  ),
                ),
              ],
            ),
          ),

          // LISTE DES RÉSULTATS
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Médicaments détectés",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: _detectedMeds.isEmpty 
                      ? const Center(child: Text("Prenez une photo de l'ordonnance"))
                      : ListView.builder(
                          itemCount: _detectedMeds.length,
                          itemBuilder: (context, index) => _buildMedItem(index),
                        ),
                  ),
                  
                  // BOUTON DE VALIDATION
                  if (_detectedMeds.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _confirmAndSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        child: const Text(
                          "Recherche les disponibilités",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildMedItem(int index) {
    bool isSelected = _detectedMeds[index]['selected'];
    return ListTile(
      leading: GestureDetector(
        onTap: () => setState(() => _detectedMeds[index]['selected'] = !isSelected),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: const Icon(Icons.check, size: 18, color: Colors.white),
        ),
      ),
      title: Text(_detectedMeds[index]['name']),
    );
  }

  void _confirmAndSearch() {
  for (var med in _detectedMeds) {
  if (med['selected']) {
    HistoryService.instance.add(med['name'], source: "Scanner");
  }
}
    // Retour à l'écran précédent
    Navigator.pop(context);
  }
}