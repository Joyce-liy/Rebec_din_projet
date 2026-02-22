import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:pharma/theme/app_theme.dart';

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

class _ChatAIScreenState extends State<ChatAIScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final PharmacyService _pharmacyService = PharmacyService();
  final LocationService _locationService = LocationService();
  
  bool _isListening = false;
  String _aiResponse = "Appuyez sur le micro pour commencer";
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
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  List<_ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _initSpeech();
    _flutterTts.awaitSpeakCompletion(true);
    _initializeTts();
    _preloadTask = _preloadData();
    
    // Add initial welcome message
    _messages.add(_ChatMessage(
      text: "Bonjour ! Je suis votre assistant PharmConnect. Comment puis-je vous aider aujourd'hui ?",
      isUser: false,
    ));
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
    _pulseController.dispose();
    super.dispose();
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: isUser));
    });
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
    const response = "Quel médicament recherchez-vous aujourd'hui ?";
    _addMessage(response, false);
    setState(() {
      _stage = _ConversationStage.awaitingMedicationName;
      _aiResponse = response;
    });
    await _speak(response);
    await _startListening(
      onFinalResult: _handleMedicationName,
      onNoMatch: _promptMedicationRepeat,
    );
  }

  Future<void> _promptMedicationRepeat() async {
    if (!mounted) return;
    const response = "Je n'ai pas saisi le nom. Pouvez-vous répéter ?";
    _addMessage(response, false);
    setState(() {
      _aiResponse = response;
    });
    await _speak(response);
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
    _addMessage(input, true);
    await _processMedicationRequest(input);
  }

  Future<void> _processMedicationRequest(String medicationQuery) async {
    if (!mounted) return;
    final searchingMsg = "Je recherche $medicationQuery...";
    _addMessage(searchingMsg, false);
    setState(() {
      _aiResponse = searchingMsg;
    });

    try {
      final Future<GeoPoint?> locationFuture = _getUserLocation();
      final List<MedicationCatalogEntry> catalog = await _ensureCatalogLoaded();
      final List<MedicationCatalogEntry> matches =
          _searchCatalog(medicationQuery, catalog);
      
      if (matches.isEmpty) {
        const noResultMsg = "Je n'ai trouvé aucune pharmacie proposant ce médicament.";
        _addMessage(noResultMsg, false);
        if (!mounted) return;
        setState(() {
          _stage = _ConversationStage.idle;
          _currentOptions = const [];
          _selectedOption = null;
          _aiResponse = noResultMsg;
        });
        await _speak(noResultMsg);
        return;
      }

      final MedicationCatalogEntry entry =
          _selectBestMatch(medicationQuery, matches);
      final GeoPoint? location = await locationFuture;
      final List<_PharmacyOption> options = _buildOptions(entry, location);

      if (options.isEmpty) {
        const noLocationMsg = "Aucune pharmacie avec localisation disponible.";
        _addMessage(noLocationMsg, false);
        if (!mounted) return;
        setState(() {
          _stage = _ConversationStage.idle;
          _aiResponse = noLocationMsg;
        });
        await _speak(noLocationMsg);
        return;
      }

      if (!mounted) return;
      _currentOptions = options;
      _selectedOption = null;
      await _presentOptions(entry, location);
    } catch (e) {
      const errorMsg = "Une erreur est survenue. Réessayez plus tard.";
      _addMessage(errorMsg, false);
      if (!mounted) return;
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = errorMsg;
      });
      await _speak(errorMsg);
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
    final List<_PharmacyOption> options =
        entry.availabilities.map((availability) {
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
      return _PharmacyOption(
          availability: availability, distanceMeters: distance);
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
    final String summary =
        _buildSummaryMessage(entry.nom, _currentOptions, location);
    _addMessage(summary, false);
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
    buffer.writeln('J\'ai trouvé ${options.length} pharmacies pour $medicationName :');
    for (var i = 0; i < options.length; i++) {
      final option = options[i];
      final pharmacy = option.pharmacy;
      final String distanceLabel = option.distanceMeters != null
          ? ' à ${_formatDistance(option.distanceMeters!)}'
          : '';
      buffer.writeln('${i + 1}. ${pharmacy.nom}$distanceLabel');
    }
    buffer.writeln('Dites le numéro de la pharmacie souhaitée.');
    return buffer.toString();
  }

  Future<void> _promptPharmacySelection() async {
    if (!mounted) return;
    const prompt = 'Quelle pharmacie choisissez-vous ?';
    _addMessage(prompt, false);
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
    _addMessage(input, true);
    
    if (_currentOptions.isEmpty) {
      const noOptions = 'Aucune pharmacie disponible.';
      _addMessage(noOptions, false);
      if (!mounted) return;
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = noOptions;
      });
      await _speak(noOptions);
      return;
    }

    final _PharmacyOption? selected = _matchPharmacyOption(input);
    if (selected == null) {
      const retry = "Je n'ai pas compris. Répétez le numéro.";
      _addMessage(retry, false);
      await _speak(retry);
      await _startListening(onFinalResult: _handlePharmacySelection);
      return;
    }

    if (!mounted) return;
    _selectedOption = selected;
    _stage = _ConversationStage.awaitingNavigationConfirmation;
    final prompt =
        "Vous avez choisi ${selected.pharmacy.nom}. Voulez-vous l'itinéraire ?";
    _addMessage(prompt, false);
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
      'un': 1, 'une': 1, 'premier': 1,
      'deux': 2, 'deuxieme': 2,
      'trois': 3, 'troisieme': 3,
      'quatre': 4, 'quatrieme': 4,
      'cinq': 5, 'cinquieme': 5,
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
      const noSelection = "Aucune pharmacie sélectionnée.";
      _addMessage(noSelection, false);
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = noSelection;
      });
      await _speak(noSelection);
      return;
    }

    final prompt =
        "Lancer l'itinéraire vers ${_selectedOption!.pharmacy.nom} ?";
    _addMessage(prompt, false);
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
    _addMessage(input, true);
    
    if (!mounted) return;
    final _PharmacyOption? option = _selectedOption;
    if (option == null) {
      const noPharmacy = "Pas de pharmacie sélectionnée.";
      _addMessage(noPharmacy, false);
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = noPharmacy;
      });
      await _speak(noPharmacy);
      return;
    }

    final String normalizedInput = _normalizeText(input);
    final bool isPositive =
        normalizedInput.contains('oui') || normalizedInput.contains('yes');
    final bool isNegative =
        normalizedInput.contains('non') || normalizedInput.contains('no');

    if (!isPositive && !isNegative) {
      const clarify = "Répondez par oui ou non.";
      _addMessage(clarify, false);
      await _speak(clarify);
      await _startListening(onFinalResult: _handleNavigationResponse);
      return;
    }

    if (isNegative) {
      const cancelled = "D'accord, l'itinéraire n'est pas lancé.";
      _addMessage(cancelled, false);
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = cancelled;
        _currentOptions = const [];
        _selectedOption = null;
      });
      await _speak(cancelled);
      return;
    }

    final Pharmacy pharmacy = option.pharmacy;
    final GeoLocationPoint? point = pharmacy.localisation;

    if (point == null) {
      const noLoc = "Localisation non disponible pour cette pharmacie.";
      _addMessage(noLoc, false);
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = noLoc;
        _currentOptions = const [];
        _selectedOption = null;
      });
      await _speak(noLoc);
      return;
    }

    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}&travelmode=driving',
    );

    final bool launched =
        await launchUrl(url, mode: LaunchMode.externalApplication);
    final successMsg = launched
        ? "J'ai ouvert l'itinéraire vers ${pharmacy.nom}."
        : "Impossible d'ouvrir l'itinéraire.";
    _addMessage(successMsg, false);
    setState(() {
      _stage = _ConversationStage.idle;
      _aiResponse = successMsg;
      _currentOptions = const [];
      _selectedOption = null;
    });
    await _speak(successMsg);
  }

  Future<void> _startListening({
    required Future<void> Function(String) onFinalResult,
    Future<void> Function()? onNoMatch,
  }) async {
    final bool available = _speechToText.isAvailable ||
        await _speechToText.initialize(
          onError: (error) =>
              debugPrint("Erreur reconnaissance : ${error.errorMsg}"),
        );

    if (!available) {
      const notAvailable = "Micro non disponible.";
      _addMessage(notAvailable, false);
      if (!mounted) return;
      setState(() {
        _stage = _ConversationStage.idle;
        _aiResponse = notAvailable;
      });
      await _speak(notAvailable);
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
    _addMessage(message, false);
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
          message: "Je n'ai pas compris. Répétez.",
          finalCallback: finalCallback,
          retryCallback: retryCallback,
        );
      });
      return;
    }

    _clearPendingCallbacks();
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
      'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e',
      'ê': 'e', 'ë': 'e', 'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u', 'ÿ': 'y',
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
        debugPrint('Localisation indisponible: $e');
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
      debugPrint('Erreur préchargement: $e');
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
      debugPrint('Erreur localisation: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Chat messages
            Expanded(
              child: _buildChatArea(),
            ),
            
            // Mic control
            _buildMicControl(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm, AppSpacing.md, AppSpacing.xl, AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.slate600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Assistant PharmConnect",
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "En ligne",
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _buildMessageBubble(message);
        },
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: message.isUser
                    ? AppColors.primaryGradient
                    : null,
                color: message.isUser ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                boxShadow: AppShadows.soft,
              ),
              child: Text(
                message.text,
                style: AppTypography.bodyMedium.copyWith(
                  color: message.isUser ? Colors.white : AppColors.slate700,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.slate200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_rounded,
                color: AppColors.slate500,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMicControl() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.slate900.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Listening indicator
          AnimatedOpacity(
            opacity: _isListening ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Je vous écoute...",
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Mic button
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isListening ? _pulseAnimation.value : 1.0,
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: _isListening
                          ? const LinearGradient(
                              colors: [AppColors.error, Color(0xFFFF6B6B)],
                            )
                          : AppColors.heroGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening
                                  ? AppColors.error
                                  : AppColors.primary)
                              .withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          Text(
            _isListening
                ? "Parlez maintenant..."
                : "Appuyez pour parler",
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}