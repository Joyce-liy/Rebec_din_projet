import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/utils/geo_utils.dart';

enum _ConversationStage {
  idle,
  awaitingMedicationName,
  awaitingPharmacyChoice,
  awaitingNavigationConfirmation,
}

class _PharmacyOption {
  const _PharmacyOption({
    required this.availability,
    this.distanceMeters,
  });

  final MedicationAvailability availability;
  final double? distanceMeters;

  Pharmacy get pharmacy => availability.pharmacy;
  PharmacyMedication get medication => availability.medication;
}

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final PharmacyService _pharmacyService = PharmacyService();
  final LocationService _locationService = LocationService();
  bool _isListening = false;
  String _aiResponse = "Appuyez sur le micro pour parler";
  _ConversationStage _stage = _ConversationStage.idle;
  List<_PharmacyOption> _currentOptions = const [];
  _PharmacyOption? _selectedOption;
  Future<void> Function(String)? _pendingOnFinalResult;
  Future<void> Function()? _pendingOnNoMatch;
  Future<void>? _preloadTask;
  List<MedicationCatalogEntry>? _catalogCache;
  GeoPoint? _lastKnownUserLocation;
  bool _isPreloading = false;
  bool _ttsReady = false;
  Future<void>? _ttsInitTask;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _flutterTts.awaitSpeakCompletion(true);
    _initializeTts();
    _preloadTask = _preloadData();
  }

  void _initSpeech() async {
    try {
      await _speechToText.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
    } catch (e) {
      debugPrint("Erreur d'initialisation : $e");
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speechToText.stop();
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }

    switch (_stage) {
      case _ConversationStage.idle:
        await _startMedicationInquiry();
        break;
      case _ConversationStage.awaitingMedicationName:
        await _promptMedicationRepeat();
        break;
      case _ConversationStage.awaitingPharmacyChoice:
        await _promptPharmacySelection();
        break;
      case _ConversationStage.awaitingNavigationConfirmation:
        await _promptNavigationConfirmation();
        break;
    }
  }

  Future<void> _startMedicationInquiry() async {
    if (!mounted) return;
    setState(() {
      _stage = _ConversationStage.awaitingMedicationName;
      _aiResponse =
          "Bonjour ! Je suis votre assistant santé. Quel médicament souhaitez-vous aujourd'hui ?";
    });
    await _speak(_aiResponse);
    await _startListening(
      onFinalResult: _handleMedicationName,
      onNoMatch: _promptMedicationRepeat,
    );
  }

  Future<void> _promptMedicationRepeat() async {
    if (!mounted) return;
    setState(() {
      _aiResponse = "Je n'ai pas saisi le nom du médicament. Pouvez-vous répéter ?";
    });
    await _speak(_aiResponse);
    await _startListening(
      onFinalResult: _handleMedicationName,
      onNoMatch: _promptMedicationRepeat,
    );
  }

  Future<void> _handleMedicationName(String input) async {
    if (input.isEmpty) {
      await _promptMedicationRepeat();
      return;
    }
    await _processMedicationRequest(input);
  }

  Future<void> _processMedicationRequest(String medicationQuery) async {
    if (!mounted) return;
    setState(() {
      _aiResponse = "Je recherche $medicationQuery autour de vous...";
    });

    try {
      final Future<GeoPoint?> locationFuture = _getUserLocation();
      final List<MedicationCatalogEntry> catalog = await _ensureCatalogLoaded();
      final List<MedicationCatalogEntry> matches =
          _searchCatalog(medicationQuery, catalog);
      if (matches.isEmpty) {
        if (!mounted) return;
        setState(() {
          _stage = _ConversationStage.idle;
          _currentOptions = const [];
          _selectedOption = null;
          _aiResponse =
              "Je n'ai trouvé aucune pharmacie proposant $medicationQuery pour le moment.";
        });
        await _speak(_aiResponse);
        return;
      }

      final MedicationCatalogEntry entry =
          _selectBestMatch(medicationQuery, matches);
      final GeoPoint? location = await locationFuture;
      final List<_PharmacyOption> options = _buildOptions(entry, location);

      if (options.isEmpty) {
        if (!mounted) return;
        setState(() {
          _stage = _ConversationStage.idle;
          _aiResponse =
              "Les pharmacies référencées n'ont pas de localisation disponible pour $medicationQuery.";
        });
        await _speak(_aiResponse);
        return;
      }

      if (!mounted) return;
      _currentOptions = options;
      _selectedOption = null;
      await _presentOptions(entry, location);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = "Une erreur est survenue pendant la recherche : $e";
      });
      await _speak("Je rencontre un problème pour effectuer la recherche. Réessayez plus tard.");
    }
  }

  MedicationCatalogEntry _selectBestMatch(
      String query, List<MedicationCatalogEntry> matches) {
    final String normalizedQuery = _normalizeText(query);
    return matches.firstWhere(
      (entry) => _normalizeText(entry.nom) == normalizedQuery,
      orElse: () => matches.first,
    );
  }

  List<MedicationCatalogEntry> _searchCatalog(
    String query,
    List<MedicationCatalogEntry> catalog,
  ) {
    if (query.trim().isEmpty) {
      return List<MedicationCatalogEntry>.from(catalog);
    }
    final String lower = query.toLowerCase();
    return catalog
        .where((entry) =>
            entry.nom.toLowerCase().contains(lower) ||
            entry.dosage.toLowerCase().contains(lower))
        .toList();
  }

  List<_PharmacyOption> _buildOptions(
      MedicationCatalogEntry entry, GeoPoint? userLocation) {
    final List<_PharmacyOption> options = entry.availabilities.map((availability) {
      final GeoLocationPoint? point = availability.pharmacy.localisation;
      double? distance;
      if (userLocation != null && point != null) {
        distance = GeoUtils.haversineDistance(
          startLat: userLocation.latitude,
          startLng: userLocation.longitude,
          endLat: point.latitude,
          endLng: point.longitude,
        );
      }
      return _PharmacyOption(availability: availability, distanceMeters: distance);
    }).toList();

    if (userLocation != null) {
      options.sort((a, b) {
        final double? distanceA = a.distanceMeters;
        final double? distanceB = b.distanceMeters;
        if (distanceA == null && distanceB == null) return 0;
        if (distanceA == null) return 1;
        if (distanceB == null) return -1;
        return distanceA.compareTo(distanceB);
      });
    }

    return options.take(5).toList();
  }

  Future<void> _presentOptions(
      MedicationCatalogEntry entry, GeoPoint? location) async {
    if (!mounted) return;
    final String summary = _buildSummaryMessage(entry.nom, _currentOptions, location);
    setState(() {
      _stage = _ConversationStage.awaitingPharmacyChoice;
      _aiResponse = summary;
    });
    await _speak(summary);
    await _startListening(
      onFinalResult: _handlePharmacySelection,
      onNoMatch: _promptPharmacySelection,
    );
  }

  String _buildSummaryMessage(
    String medicationName,
    List<_PharmacyOption> options,
    GeoPoint? location,
  ) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('Voici les pharmacies proposant $medicationName :');
    for (var i = 0; i < options.length; i++) {
      final option = options[i];
      final pharmacy = option.pharmacy;
      final statusLabel = option.medication.status.label;
      final price = option.medication.prix;
      final String priceLabel = price > 0 ? ' • ~${price.toStringAsFixed(0)} FCFA' : '';
      final String distanceLabel = option.distanceMeters != null
          ? ' • à ${_formatDistance(option.distanceMeters!)}'
          : '';
      buffer.writeln(
        '${i + 1}. ${pharmacy.nom} ($statusLabel$distanceLabel$priceLabel)',
      );
    }

    final _PharmacyOption nearest = options.firstWhere(
      (option) => option.distanceMeters != null,
      orElse: () => options.first,
    );

    if (nearest.distanceMeters != null) {
      buffer.writeln(
        'La pharmacie la plus proche est ${nearest.pharmacy.nom}, située à ${_formatDistance(nearest.distanceMeters!)}.',
      );
    } else if (location == null) {
      buffer.writeln(
        'Activez la localisation pour obtenir la pharmacie la plus proche.',
      );
    }

    buffer.writeln(
        'Quelle pharmacie souhaitez-vous choisir ? Dites le numéro ou le nom.');

    return buffer.toString();
  }

  Future<void> _promptPharmacySelection() async {
    if (!mounted) return;
    final String prompt =
        'Quelle pharmacie souhaitez-vous choisir ? Dites le numéro ou le nom.';
    setState(() {
      _stage = _ConversationStage.awaitingPharmacyChoice;
      _aiResponse = prompt;
    });
    await _speak(prompt);
    await _startListening(
      onFinalResult: _handlePharmacySelection,
      onNoMatch: _promptPharmacySelection,
    );
  }

  Future<void> _handlePharmacySelection(String input) async {
    if (_currentOptions.isEmpty) {
      if (!mounted) return;
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = 'Aucune pharmacie n\'est disponible pour le moment.';
      });
      await _speak(_aiResponse);
      return;
    }

    final _PharmacyOption? selected = _matchPharmacyOption(input);
    if (selected == null) {
      await _speak(
          "Je n'ai pas compris votre choix. Répétez le numéro ou le nom de la pharmacie.");
      await _startListening(onFinalResult: _handlePharmacySelection);
      return;
    }

    if (!mounted) return;
    _selectedOption = selected;
    _stage = _ConversationStage.awaitingNavigationConfirmation;
    final String prompt =
        "Vous avez choisi ${selected.pharmacy.nom}. Souhaitez-vous lancer l'itinéraire ? (oui ou non)";
    setState(() {
      _aiResponse = prompt;
    });
    await _speak(prompt);
    await _startListening(onFinalResult: _handleNavigationResponse);
  }

  _PharmacyOption? _matchPharmacyOption(String input) {
    if (input.isEmpty) return null;
    final String normalizedInput = _normalizeText(input);

    final Map<String, int> numberWords = {
      'un': 1,
      'une': 1,
      'premier': 1,
      'deux': 2,
      'trois': 3,
      'troisieme': 3,
      'quatre': 4,
      'quatrieme': 4,
      'cinq': 5,
      'cinquieme': 5,
    };

    for (final entry in numberWords.entries) {
      if (normalizedInput.contains(entry.key)) {
        final int index = entry.value;
        if (index >= 1 && index <= _currentOptions.length) {
          return _currentOptions[index - 1];
        }
      }
    }

    final RegExp numberRegex = RegExp(r'(\d+)');
    final Match? numberMatch = numberRegex.firstMatch(normalizedInput);
    if (numberMatch != null) {
      final int? index = int.tryParse(numberMatch.group(1) ?? '');
      if (index != null && index >= 1 && index <= _currentOptions.length) {
        return _currentOptions[index - 1];
      }
    }

    for (final option in _currentOptions) {
      final String normalizedName = _normalizeText(option.pharmacy.nom);
      if (normalizedInput.contains(normalizedName) ||
          normalizedName.contains(normalizedInput)) {
        return option;
      }
    }

    return null;
  }

  Future<void> _promptNavigationConfirmation() async {
    if (_selectedOption == null || !mounted) {
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = "Aucune pharmacie sélectionnée.";
      });
      await _speak(_aiResponse);
      return;
    }

    final String prompt =
        "Voulez-vous que je lance l'itinéraire vers ${_selectedOption!.pharmacy.nom} ? Dites oui ou non.";
    setState(() {
      _stage = _ConversationStage.awaitingNavigationConfirmation;
      _aiResponse = prompt;
    });
    await _speak(prompt);
    await _startListening(
      onFinalResult: _handleNavigationResponse,
      onNoMatch: _promptNavigationConfirmation,
    );
  }

  Future<void> _handleNavigationResponse(String input) async {
    if (!mounted) return;
    final _PharmacyOption? option = _selectedOption;
    if (option == null) {
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = "Je n'ai pas de pharmacie sélectionnée.";
      });
      await _speak(_aiResponse);
      return;
    }

    final String normalizedInput = _normalizeText(input);
    final bool isPositive =
        normalizedInput.contains('oui') || normalizedInput.contains('yes');
    final bool isNegative =
        normalizedInput.contains('non') || normalizedInput.contains('no');

    if (!isPositive && !isNegative) {
      await _speak("Répondez par oui ou non, s'il vous plaît.");
      await _startListening(onFinalResult: _handleNavigationResponse);
      return;
    }

    if (isNegative) {
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse =
            "Très bien, l'itinéraire ne sera pas lancé. N'hésitez pas à me demander autre chose.";
        _currentOptions = const [];
        _selectedOption = null;
      });
      await _speak(_aiResponse);
      return;
    }

    final Pharmacy pharmacy = option.pharmacy;
    final GeoLocationPoint? point = pharmacy.localisation;

    if (point == null) {
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse =
            "La localisation de ${pharmacy.nom} n'est pas disponible. Impossible de lancer l'itinéraire.";
        _currentOptions = const [];
        _selectedOption = null;
      });
      await _speak(_aiResponse);
      return;
    }

    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}&travelmode=driving',
    );

    final bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (launched) {
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse =
            "J'ai ouvert l'itinéraire vers ${pharmacy.nom} dans votre application de cartes.";
        _currentOptions = const [];
        _selectedOption = null;
      });
      await _speak(_aiResponse);
    } else {
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse =
            "Je n'ai pas pu ouvrir l'itinéraire. Vérifiez votre connexion et réessayez.";
        _currentOptions = const [];
        _selectedOption = null;
      });
      await _speak(_aiResponse);
    }
  }

  Future<void> _startListening({
    required Future<void> Function(String) onFinalResult,
    Future<void> Function()? onNoMatch,
  }) async {
    final bool available = _speechToText.isAvailable ||
        await _speechToText.initialize(
          onError: (error) => debugPrint("Erreur reconnaissance : ${error.errorMsg}"),
        );

    if (!available) {
      if (!mounted) return;
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = "Micro non autorisé ou non disponible.";
      });
      await _speak(_aiResponse);
      return;
    }

    if (!mounted) return;
    setState(() => _isListening = true);

    _pendingOnFinalResult = onFinalResult;
    _pendingOnNoMatch = onNoMatch;

    _speechToText.listen(
      listenMode: ListenMode.dictation,
      localeId: 'fr_FR',
      cancelOnError: true,
      partialResults: false,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 10),
      onResult: (result) async {
        if (!result.finalResult) return;
        await _speechToText.stop();
        if (mounted) {
          setState(() => _isListening = false);
        }
        final String recognized = result.recognizedWords.trim();
        if (recognized.isEmpty) {
          await _handleRepeatRequest(
            message: "Je n'ai pas compris. Pouvez-vous répéter ?",
            finalCallback: onFinalResult,
            retryCallback: onNoMatch,
          );
          return;
        }
        await onFinalResult(recognized);
        _clearPendingCallbacks();
      },
    );
  }

  Future<void> _handleRepeatRequest({
    required String message,
    Future<void> Function(String)? finalCallback,
    Future<void> Function()? retryCallback,
  }) async {
    if (retryCallback != null) {
      await retryCallback();
      return;
    }

    if (!mounted || finalCallback == null) return;
    setState(() {
      _aiResponse = message;
    });
    await _speak(_aiResponse);
    await _startListening(
      onFinalResult: finalCallback,
      onNoMatch: retryCallback,
    );
  }

  void _clearPendingCallbacks() {
    _pendingOnFinalResult = null;
    _pendingOnNoMatch = null;
  }

  void _onSpeechStatus(String status) {
    if (status == 'notListening' && mounted) {
      setState(() => _isListening = false);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint("Erreur reconnaissance : ${error.errorMsg}");
    _speechToText.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }

    final Future<void> Function(String)? finalCallback = _pendingOnFinalResult;
    final Future<void> Function()? retryCallback = _pendingOnNoMatch;

    if (error.errorMsg == 'error_no_match' && finalCallback != null) {
      Future.microtask(() async {
        await _handleRepeatRequest(
          message: "Je n'ai pas compris. Pouvez-vous répéter ?",
          finalCallback: finalCallback,
          retryCallback: retryCallback,
        );
      });
      return;
    }

    _clearPendingCallbacks();

    final String message;
    switch (error.errorMsg) {
      case 'error_network':
      case 'error_network_timeout':
        message =
            "Je ne parviens pas à me connecter au service de reconnaissance. Vérifiez votre connexion puis appuyez à nouveau sur le micro.";
        break;
      case 'error_busy':
      case 'error_audio':
      case 'error_server':
      case 'error_client':
        message =
            "Le micro est momentanément indisponible. Patientez quelques secondes puis relancez le micro.";
        break;
      default:
        message =
            "Je rencontre un problème avec la reconnaissance vocale. Appuyez à nouveau sur le micro pour réessayer.";
        break;
    }

    Future.microtask(() async {
      await _handleFatalListeningError(message);
    });
  }

  Future<void> _speak(String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _initializeTts();
    if (!_ttsReady) return;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Erreur arrêt TTS : $e');
    }
    try {
      await _flutterTts.speak(trimmed);
    } catch (e) {
      debugPrint('Erreur lancement TTS : $e');
    }
  }

  String _formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String _normalizeText(String value) {
    final String lower = value.toLowerCase();
    const Map<String, String> replacements = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ÿ': 'y',
    };
    return lower
        .split('')
        .map((char) => replacements[char] ?? char)
        .join()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .trim();
  }

  Future<void> _initializeTts() async {
    if (_ttsReady) return;
    if (_ttsInitTask != null) {
      await _ttsInitTask;
      return;
    }
    _ttsInitTask = () async {
      try {
        await _flutterTts.awaitSpeakCompletion(true);
        await _flutterTts.setLanguage('fr-FR');
        await _flutterTts.setSpeechRate(0.95);
        await _flutterTts.setVolume(1.0);
        _ttsReady = true;
      } catch (e) {
        debugPrint('Erreur initialisation TTS : $e');
        _ttsReady = false;
      }
    }();
    await _ttsInitTask;
  }

  Future<void> _preloadData() async {
    if (_isPreloading) return;
    _isPreloading = true;
    try {
      final List<MedicationCatalogEntry> catalog =
          await _pharmacyService.fetchCatalog();
      GeoPoint? location;
      try {
        location = await _locationService
            .tryGetCurrentPosition()
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Localisation indisponible durant le préchargement: $e');
      }

      if (!mounted) {
        _catalogCache = catalog;
        _lastKnownUserLocation = location;
        return;
      }

      setState(() {
        _catalogCache = catalog;
        if (location != null) {
          _lastKnownUserLocation = location;
        }
      });
    } catch (e) {
      debugPrint('Erreur préchargement catalogue: $e');
    } finally {
      _isPreloading = false;
    }
  }

  Future<List<MedicationCatalogEntry>> _ensureCatalogLoaded() async {
    if (_catalogCache != null) {
      return _catalogCache!;
    }
    if (_preloadTask == null) {
      _preloadTask = _preloadData();
    }
    await _preloadTask;
    return _catalogCache ?? await _pharmacyService.fetchCatalog();
  }

  Future<GeoPoint?> _getUserLocation() async {
    if (_lastKnownUserLocation != null) {
      return _lastKnownUserLocation;
    }
    try {
      final GeoPoint? location = await _locationService
          .tryGetCurrentPosition()
          .timeout(const Duration(seconds: 5));
      if (location != null) {
        _lastKnownUserLocation = location;
      }
      return location;
    } catch (e) {
      debugPrint('Erreur récupération localisation: $e');
      return null;
    }
  }

  Future<void> _handleFatalListeningError(String message) async {
    if (!mounted) return;
    setState(() {
      _stage = _ConversationStage.idle;
      _aiResponse = message;
      _isListening = false;
    });
    await _speak(message);
  }

  Widget _buildResponseCard() {
    final List<String> lines = _aiResponse
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final bool multipleLines = lines.length > 1;
    final List<Color> gradientColors = _isListening
        ? [const Color(0xFF66BB6A), const Color(0xFF2E7D32)]
        : [Colors.white, const Color(0xFFF8FBF6)];
    final Color primaryTextColor =
        _isListening ? Colors.white : const Color(0xFF1F4137);
    final Color secondaryTextColor =
        _isListening ? Colors.white70 : const Color(0xFF5E7A72);
    final Color accentColor =
        _isListening ? Colors.white : const Color(0xFF2E7D32);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? Colors.white.withOpacity(0.25)
                      : const Color(0xFFE8F5E9),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assistant Pharma IA',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isListening
                        ? 'Je vous écoute...'
                        : 'Prêt à vous accompagner',
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...lines.map(
            (line) => Padding(
              padding:
                  EdgeInsets.only(bottom: line == lines.last ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (multipleLines)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.fiber_manual_record,
                        size: 8,
                        color: accentColor,
                      ),
                    ),
                  if (multipleLines) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: primaryTextColor,
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

  Widget _buildMicControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: _toggleListening,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _isListening ? const Color(0xFFE53935) : const Color(0xFF2E7D32),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(28),
            elevation: 12,
            shadowColor: Colors.black26,
          ),
          child: Icon(
            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isListening
              ? 'Parlez, je suis à votre écoute.'
              : 'Appuyez pour me demander un médicament.',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2E7D32),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F1),
      appBar: AppBar(
        title: const Text("Assistant Pharma IA"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F4137),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: _buildResponseCard(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildMicControl(),
          ],
        ),
      ),
    );
  }
}