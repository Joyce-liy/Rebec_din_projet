import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pharma/services/gemini_service.dart';
import 'package:pharma/services/history_service.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isImporting = false;
  bool _isProcessing = false;
  final List<_CadnetDocument> _cadnetDocuments = [];
  List<Map<String, dynamic>> _detectedMeds = [];

  Future<void> _importCadnetDocuments() async {
    if (_isImporting || _isProcessing) return;

    setState(() => _isImporting = true);

    try {
      final images = await _imagePicker.pickMultiImage(imageQuality: 92);
      if (images.isEmpty) {
        return;
      }

      final imported = <_CadnetDocument>[];
      for (final image in images) {
        final bytes = await image.readAsBytes();
        imported.add(
          _CadnetDocument(
            name: image.name.isNotEmpty ? image.name : 'Document Cadnet',
            bytes: bytes,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _cadnetDocuments
          ..clear()
          ..addAll(imported);
        _detectedMeds = [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur d'importation : $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _analyzeImportedCadnet() async {
    if (_cadnetDocuments.isEmpty || _isProcessing) {
      if (_cadnetDocuments.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Importez d'abord le Cadnet avant l'analyse."),
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final orderedNames = <String>[];
      final seenNames = <String>{};

      for (final document in _cadnetDocuments) {
        final result =
            await GeminiService.readHandwrittenPrescription(document.bytes);
        for (final name in result) {
          final cleanName = name.trim();
          final key = cleanName.toLowerCase();
          if (cleanName.isNotEmpty && seenNames.add(key)) {
            orderedNames.add(cleanName);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _detectedMeds = orderedNames
            .map((name) => {'name': name, 'selected': true})
            .toList();
        _isProcessing = false;
      });

      if (_detectedMeds.isNotEmpty) {
        _showResultsSheet();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Aucun medicament detecte dans les documents importes.",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  void _clearCadnet() {
    if (_isProcessing) return;
    setState(() {
      _cadnetDocuments.clear();
      _detectedMeds = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasCadnet = _cadnetDocuments.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cadnet importe',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.folder_copy_rounded,
                      color: Color(0xFF059669),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Importer le Cadnet',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "L'analyse se fait uniquement sur les documents deja importes depuis votre Cadnet.",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed:
                          _isImporting ? null : _importCadnetDocuments,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_file_rounded),
                      label: Text(
                        hasCadnet ? 'Remplacer le Cadnet' : 'Importer Cadnet',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (hasCadnet) _buildImportedDocuments(),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed:
                    hasCadnet && !_isProcessing ? _analyzeImportedCadnet : null,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.document_scanner_rounded),
                label: Text(
                  _isProcessing
                      ? 'Analyse du Cadnet...'
                      : 'Analyser les documents importes',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportedDocuments() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.description_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_cadnetDocuments.length} document${_cadnetDocuments.length > 1 ? 's' : ''} importe${_cadnetDocuments.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _clearCadnet,
                  child: const Text('Retirer'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ..._cadnetDocuments.map(
            (document) => ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  document.bytes,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                document.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              subtitle: const Text('Pret pour analyse'),
            ),
          ),
        ],
      ),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Medicaments identifies',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Deselectionnez si necessaire',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _detectedMeds.length,
                  itemBuilder: (context, i) => CheckboxListTile(
                    activeColor: Colors.green,
                    title: Text(
                      _detectedMeds[i]['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    value: _detectedMeds[i]['selected'] as bool,
                    onChanged: (val) => setSheetState(
                      () => _detectedMeds[i]['selected'] = val,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    final selectedMedications = _detectedMeds
                        .where((med) => med['selected'] == true)
                        .map((med) => med['name'] as String)
                        .toList();

                    for (final medName in selectedMedications) {
                      HistoryService.instance.add(
                        medName,
                        source: 'Cadnet',
                      );
                    }

                    Navigator.pop(context);
                    Navigator.pop(context, selectedMedications);
                  },
                  child: const Text(
                    'RECHERCHER',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CadnetDocument {
  const _CadnetDocument({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}
