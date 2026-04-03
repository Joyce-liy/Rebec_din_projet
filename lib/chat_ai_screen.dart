import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/services/gemini_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:pharma/theme/app_theme.dart';

// ===========================================================
// ÉNUMÉRATIONS & MODÈLES INTERNES
// ===========================================================

enum _ConversationStage {
  idle,

  /// Consultation symptômes — on attend les infos allergies + médicaments du jour
  awaitingAllergyInfo,

  /// L'utilisateur choisit une pharmacie dans la liste
  awaitingPharmacyChoice,

  /// L'utilisateur choisit une action (itinéraire / conseils / autre médicament)
  awaitingActionChoice,
}

/// Données collectées pendant une consultation symptomatique
class _ConsultationData {
  final String symptoms;
  String? allergyAndMedsInfo;

  _ConsultationData({required this.symptoms});
}

class _PharmacyOption {
  const _PharmacyOption({required this.pharmacy, this.distanceMeters});
  final Pharmacy pharmacy;
  final double? distanceMeters;
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});

  String get role => isUser ? 'Utilisateur' : 'REBEC-DIN';
}

// ===========================================================
// WIDGET PRINCIPAL
// ===========================================================

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  // ---- Services ----
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final PharmacyService _pharmacyService = PharmacyService();
  final LocationService _locationService = LocationService();
  final GeminiService _geminiService = GeminiService();

  // ---- UI ----
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ---- État conversation ----
  _ConversationStage _stage = _ConversationStage.idle;
  bool _isProcessing = false;

  // ---- Vocal ----
  bool _speechAvailable = false;
  bool _isListening = false;

  // ---- Données métier ----
  List<_PharmacyOption> _currentOptions = [];
  _PharmacyOption? _selectedOption;
  String? _lastMedicationQuery;
  int? _recommendedIndex;

  // ---- Consultation symptomatique ----
  _ConsultationData? _currentConsultation;

  // ---- Historique messages ----
  final List<_ChatMessage> _messages = [];
  static const int _contextWindowSize = 5;

  // ===========================================================
  // CYCLE DE VIE
  // ===========================================================

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _flutterTts.awaitSpeakCompletion(true);
    _configureTts();

    // Message d'accueil empathique (amélioration #1)
    _addAIMessage(
      "Bonjour ! Je suis REBEC-DIN, votre pharmacien virtuel a Yaounde.\n"
      "Comment vous sentez-vous aujourd'hui ? "
      "Dites-moi ce qui vous amene ou nommez le medicament que vous recherchez.",
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  // ===========================================================
  // INITIALISATION VOCAL
  // ===========================================================

  Future<void> _initSpeech() async {
    final available = await _speechToText.initialize(
      onError: (e) => debugPrint('[STT] Erreur : $e'),
    );
    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage('fr-FR');
    await _flutterTts.setSpeechRate(0.48);
    await _flutterTts.setPitch(1.0);

    final voices = await _flutterTts.getVoices;
    if (voices is List) {
      for (final v in voices) {
        if (v is Map) {
          final locale = (v['locale'] ?? v['language'] ?? '').toString();
          if (locale.toLowerCase().startsWith('fr')) {
            await _flutterTts.setVoice(Map<String, String>.from(v));
            break;
          }
        }
      }
    }
  }

  // ===========================================================
  // CONTEXTE CONVERSATIONNEL (amélioration #2)
  // ===========================================================

  String _buildConversationContext() {
    final window = _messages.length > _contextWindowSize
        ? _messages.sublist(_messages.length - _contextWindowSize)
        : List<_ChatMessage>.from(_messages);
    return window.map((m) => '${m.role}: ${m.text}').join('\n');
  }

  // ===========================================================
  // DÉTECTIONS LOCALES (sans appel API — instantané)
  // ===========================================================

  bool _isGreeting(String value) {
    final raw = value.trim().toLowerCase();
    return raw == 'bonjour' ||
        raw == 'salut' ||
        raw == 'bonsoir' ||
        raw == 'coucou' ||
        raw == 'hey' ||
        raw == 'hello' ||
        raw == 'hi' ||
        raw == 'salam';
  }

  /// Détecte si l'utilisateur décrit des symptômes (vs demander un médicament précis)
  bool _isSymptomDescription(String value) {
    final lower = value.trim().toLowerCase();
    final keywords = [
      'fievre', 'fièvre', 'frisson', 'mal', 'douleur', 'toux',
      'vomis', 'diarrhee', 'diarrhée', 'fatigue', 'faible', 'fatigué',
      'pas bien', 'malade', 'grippe', 'palu', 'paludisme', 'nausee',
      'nausée', 'vertige', 'maux', 'brulure', 'brûlure', 'courbature',
      'transpire', 'sueur', 'essoufle', 'essoufflé', 'tete qui tourne',
      'pas me sentir', 'me sens pas', 'mal depuis', 'depuis hier', 'depuis ce matin',
    ];
    for (final k in keywords) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  /// Détecte une demande de localisation de pharmacie
  /// Correspond à : "Où est la pharmacie la plus proche ?" etc.
  bool _isPharmacyLocationRequest(String value) {
    final lower = value.trim().toLowerCase();
    final hasLocation = lower.contains('pharmacie') ||
        lower.contains('officine') ||
        lower.contains('ou trouver') ||
        lower.contains('où trouver');
    final hasProximity = lower.contains('proche') ||
        lower.contains('plus proche') ||
        lower.contains('autour') ||
        lower.contains('pres de') ||
        lower.contains('à cote') ||
        lower.contains('a cote') ||
        lower.contains('ou est') ||
        lower.contains('où est') ||
        lower.contains('trouver');
    return hasLocation || hasProximity;
  }

  /// Blocklist locale pour les sujets manifestement hors-domaine
  bool _isObviouslyOffTopic(String value) {
    final lower = value.trim().toLowerCase();
    final keywords = [
      'football', 'sport', 'musique', 'politique', 'meteo', 'météo',
      'recette', 'cuisine', 'cinema', 'cinéma', 'film', 'serie', 'série',
      'gaming', 'jeu video', 'informatique', 'programmation', 'codage',
      'crypto', 'bitcoin', 'framework', 'javascript', 'python', 'base de donnees',
    ];
    for (final k in keywords) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  Future<bool> _checkIsPharmacyRelated(String userInput) async {
    if (_isObviouslyOffTopic(userInput)) return false;
    try {
      return await _geminiService.isPharmacyRelated(userInput);
    } catch (_) {
      return true;
    }
  }

  // ===========================================================
  // CONSULTATION SYMPTOMATIQUE — FLOW EN 2 ÉTAPES
  // ===========================================================

  /// Étape 1 : L'IA accueille les symptômes avec empathie
  /// et pose les deux questions systématiques (allergies + médicaments du jour)
  Future<void> _startSymptomConsultation(String symptoms) async {
    _currentConsultation = _ConsultationData(symptoms: symptoms);
    _lastMedicationQuery = symptoms;

    // Message d'accueil empathique AVANT les questions (amélioration #1 du scénario)
    await _addAIMessage(
      "Je comprends, ce n'est pas agréable de se sentir ainsi. "
      "Vous avez bien fait de venir, nous allons faire le point ensemble.\n\n"
      "Avant de vous conseiller au mieux, j'ai besoin de deux informations :\n"
      "1. Avez-vous des allergies connues a des medicaments ?\n"
      "2. Avez-vous deja pris quelque chose aujourd'hui "
      "(Paracetamol, aspirine, un antipaludique...) ?",
    );
    _stage = _ConversationStage.awaitingAllergyInfo;
  }

  /// Étape 2 : L'IA reçoit les infos et conduit la consultation complète
  Future<void> _handleAllergyResponse(String response) async {
    if (_currentConsultation == null) {
      _stage = _ConversationStage.idle;
      return;
    }

    _currentConsultation!.allergyAndMedsInfo = response;
    setState(() => _isProcessing = true);

    try {
      final context = _buildConversationContext();
      final advice = await _geminiService.conductSymptomConsultation(
        _currentConsultation!.symptoms,
        allergyAndMedsInfo: response,
        context: context,
      );
      await _addAIMessage(advice);

      // Après la consultation, proposer de trouver un laboratoire / pharmacie
      await _addAIMessage(
        "Si vous souhaitez que je vous localise une pharmacie ou un laboratoire "
        "proche pour faire votre test, dites-moi : "
        "\"Ou est la pharmacie la plus proche ?\"",
      );
    } catch (_) {
      await _addAIMessage(
        "Je n'ai pas pu traiter votre consultation. "
        "Veuillez vous rendre directement chez un professionnel de sante.",
      );
    } finally {
      setState(() => _isProcessing = false);
      _stage = _ConversationStage.idle;
      _currentConsultation = null;
    }
  }

  // ===========================================================
  // COMMANDE VOCALE PHARMACIE (astuce du scénario)
  // ===========================================================

  /// Localise les pharmacies proches sans nécessiter un nom de médicament
  Future<void> _searchNearestPharmacy() async {
    setState(() => _isProcessing = true);

    await _addAIMessage(
      "Je recherche les officines autour de vous a Yaounde...",
    );

    final location = await _locationService.tryGetCurrentPosition();
    if (location == null) {
      setState(() => _isProcessing = false);
      await _addAIMessage(
        "Je n'arrive pas a acceder a votre position. "
        "Veuillez activer la localisation et reessayer.",
      );
      return;
    }

    final pharmacies = await _pharmacyService.fetchNearbyPharmacies(
      latitude: location.latitude,
      longitude: location.longitude,
    );

    setState(() => _isProcessing = false);

    if (pharmacies.isEmpty) {
      await _addAIMessage(
        "Aucune pharmacie trouvee a proximite pour le moment. Reessayez dans quelques instants.",
      );
      return;
    }

    final options = pharmacies.map((pharmacy) {
      final point = pharmacy.localisation;
      final distance = point == null
          ? null
          : GeoUtils.haversineDistance(
              startLat: location.latitude,
              startLng: location.longitude,
              endLat: point.latitude,
              endLng: point.longitude,
            );
      return _PharmacyOption(pharmacy: pharmacy, distanceMeters: distance);
    }).toList()
      ..sort((a, b) =>
          (a.distanceMeters ?? 999999).compareTo(b.distanceMeters ?? 999999));

    _currentOptions = options.take(3).toList();

    final travelTimesSeconds = <int?>[];
    for (final option in _currentOptions) {
      final point = option.pharmacy.localisation;
      if (point == null) {
        travelTimesSeconds.add(null);
        continue;
      }
      final seconds = await _pharmacyService.estimateDrivingTravelTimeSeconds(
        startLatitude: location.latitude,
        startLongitude: location.longitude,
        endLatitude: point.latitude,
        endLongitude: point.longitude,
      );
      travelTimesSeconds.add(seconds);
    }

    // Trouver la plus rapide
    int? bestIndex;
    int? bestSeconds;
    for (int i = 0; i < travelTimesSeconds.length; i++) {
      final s = travelTimesSeconds[i];
      if (s == null) continue;
      if (bestSeconds == null || s < bestSeconds) {
        bestSeconds = s;
        bestIndex = i;
      }
    }
    _recommendedIndex = bestIndex ?? 0;

    final buf = StringBuffer();
    buf.writeln("Voici les 3 officines les plus proches de vous :\n");

    if (_recommendedIndex != null) {
      final rec = _currentOptions[_recommendedIndex!];
      final s = travelTimesSeconds[_recommendedIndex!];
      final min = s == null ? null : (s / 60).round();
      // Réponse proche de l'astuce du scénario :
      // "La Pharmacie du Soleil est à seulement 5 minutes en voiture."
      if (min != null) {
        buf.writeln(
            "La pharmacie la plus rapide est ${rec.pharmacy.nom}, "
            "a seulement $min minute${min > 1 ? 's' : ''} en voiture.\n");
      }
    }

    for (int i = 0; i < _currentOptions.length; i++) {
      final opt = _currentOptions[i];
      final km = opt.distanceMeters == null
          ? ""
          : " — ${(opt.distanceMeters! / 1000).toStringAsFixed(2)} km";
      final s = travelTimesSeconds[i];
      final min = s == null ? "" : " (~${(s / 60).round()} min)";
      buf.writeln("${i + 1}. ${opt.pharmacy.nom}$km$min");
    }

    buf.write("\nTapez le numero pour lancer l'itineraire.");

    await _addAIMessage(buf.toString());
    _stage = _ConversationStage.awaitingPharmacyChoice;
  }

  // ===========================================================
  // RECHERCHE PHARMACIE POUR UN MÉDICAMENT
  // ===========================================================

  Future<void> _searchMedication(String medicationName) async {
    _lastMedicationQuery = medicationName;
    _recommendedIndex = null;
    setState(() => _isProcessing = true);

    final location = await _locationService.tryGetCurrentPosition();
    if (location == null) {
      setState(() => _isProcessing = false);
      await _addAIMessage(
        "Je n'arrive pas a acceder a votre position. "
        "Veuillez activer la localisation puis reessayez.",
      );
      return;
    }

    final pharmacies = await _pharmacyService.fetchNearbyPharmacies(
      latitude: location.latitude,
      longitude: location.longitude,
    );

    setState(() => _isProcessing = false);

    if (pharmacies.isEmpty) {
      await _addAIMessage(
        "Je ne trouve aucune pharmacie proche pour le moment. Reessayez dans quelques instants.",
      );
      return;
    }

    final options = pharmacies.map((pharmacy) {
      final point = pharmacy.localisation;
      final distance = point == null
          ? null
          : GeoUtils.haversineDistance(
              startLat: location.latitude,
              startLng: location.longitude,
              endLat: point.latitude,
              endLng: point.longitude,
            );
      return _PharmacyOption(pharmacy: pharmacy, distanceMeters: distance);
    }).toList()
      ..sort((a, b) =>
          (a.distanceMeters ?? 999999).compareTo(b.distanceMeters ?? 999999));

    _currentOptions = options.take(5).toList();

    final travelTimesSeconds = <int?>[];
    for (final option in _currentOptions) {
      final point = option.pharmacy.localisation;
      if (point == null) {
        travelTimesSeconds.add(null);
        continue;
      }
      final seconds = await _pharmacyService.estimateDrivingTravelTimeSeconds(
        startLatitude: location.latitude,
        startLongitude: location.longitude,
        endLatitude: point.latitude,
        endLongitude: point.longitude,
      );
      travelTimesSeconds.add(seconds);
    }

    int? bestIndex;
    int? bestSeconds;
    for (int i = 0; i < travelTimesSeconds.length; i++) {
      final s = travelTimesSeconds[i];
      if (s == null) continue;
      if (bestSeconds == null || s < bestSeconds) {
        bestSeconds = s;
        bestIndex = i;
      }
    }
    _recommendedIndex = bestIndex ?? 0;

    final buf = StringBuffer();
    buf.writeln(
      "Je ne peux pas verifier le stock en ligne, mais voici les pharmacies "
      "les plus proches pour $medicationName :\n",
    );

    if (_recommendedIndex != null) {
      final rec = _currentOptions[_recommendedIndex!];
      final s = travelTimesSeconds[_recommendedIndex!];
      final min = s == null ? null : (s / 60).round();
      final label = min == null
          ? "la plus proche"
          : "la plus rapide (~$min min de trajet)";
      buf.writeln("Recommandation REBEC-DIN : ${rec.pharmacy.nom} ($label)\n");
    }

    for (int i = 0; i < _currentOptions.length; i++) {
      final opt = _currentOptions[i];
      final km = opt.distanceMeters == null
          ? ""
          : " — ${(opt.distanceMeters! / 1000).toStringAsFixed(2)} km";
      final s = travelTimesSeconds[i];
      final min = s == null ? "" : " / ~${(s / 60).round()} min";
      buf.writeln("${i + 1}. ${opt.pharmacy.nom}$km$min");
    }

    buf.write("\nDites ou tapez le numero de la pharmacie souhaitee.");

    await _addAIMessage(buf.toString());
    _stage = _ConversationStage.awaitingPharmacyChoice;
  }

  // ===========================================================
  // ACTIONS SUR LA PHARMACIE SÉLECTIONNÉE
  // ===========================================================

  Future<void> _launchNavigation() async {
    final point = _selectedOption?.pharmacy.localisation;
    if (point == null) return;

    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1"
      "&destination=${point.latitude},${point.longitude}"
      "&travelmode=driving",
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    await _addAIMessage(
      "Itineraire lance vers ${_selectedOption!.pharmacy.nom}. Bon courage !",
    );
  }

  Future<void> _giveBasicAdvice() async {
    final medication = _lastMedicationQuery;
    if (medication == null || medication.trim().isEmpty) {
      await _addAIMessage("Dites-moi d'abord le nom du medicament.");
      return;
    }

    await _addAIMessage("Voici les conseils de base pour $medication...");
    setState(() => _isProcessing = true);

    try {
      final context = _buildConversationContext();
      final advice = await _geminiService.getMedicationAdvice(
        medication,
        context: context,
      );
      await _addAIMessage(advice);
    } catch (_) {
      await _addAIMessage(
        "Je n'ai pas pu recuperer les conseils. "
        "Consultez directement un pharmacien.",
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ===========================================================
  // HELPERS MESSAGES
  // ===========================================================

  Future<void> _addAIMessage(String text) async {
    if (_isListening) await _stopListening();
    setState(() => _messages.add(_ChatMessage(text: text, isUser: false)));
    _scrollToBottom();
    await _flutterTts.speak(text);
  }

  Future<void> _addUserMessage(String text) async {
    setState(() => _messages.add(_ChatMessage(text: text, isUser: true)));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ===========================================================
  // DISPATCH PRINCIPAL — CŒUR DE L'AGENT
  // ===========================================================

  Future<void> _handleInput(String value) async {
    final input = value.trim();
    if (input.isEmpty || _isProcessing) return;

    _inputController.clear();
    await _addUserMessage(input);

    // ─── 1. Salutation ───────────────────────────────────────
    if (_isGreeting(input)) {
      await _addAIMessage(
        "Bonjour ! Ravi de vous accueillir. "
        "Comment puis-je vous aider aujourd'hui ? "
        "Decrivez vos symptomes ou nommez le medicament que vous recherchez.",
      );
      return;
    }

    // ─── 2. Commande vocale pharmacie (TOUTES ÉTAPES) ────────
    // "Où est la pharmacie la plus proche ?" → réponse immédiate
    if (_isPharmacyLocationRequest(input)) {
      await _searchNearestPharmacy();
      return;
    }

    // ─── 3. Étape : awaiting allergy info ────────────────────
    if (_stage == _ConversationStage.awaitingAllergyInfo) {
      await _handleAllergyResponse(input);
      return;
    }

    // ─── 4. Étape : awaiting pharmacy choice ─────────────────
    if (_stage == _ConversationStage.awaitingPharmacyChoice) {
      final index = _parseChoice(input);
      if (index != null && index > 0 && index <= _currentOptions.length) {
        _selectedOption = _currentOptions[index - 1];
        await _addAIMessage(
          "Excellent ! Vous avez selectionne ${_selectedOption!.pharmacy.nom}.\n\n"
          "Que souhaitez-vous faire ?\n"
          "1. Lancer l'itineraire\n"
          "2. Conseils de base sur le medicament\n"
          "3. Rechercher un autre medicament",
        );
        _stage = _ConversationStage.awaitingActionChoice;
      } else {
        await _addAIMessage(
          "Je n'ai pas compris. Veuillez dire un numero entre 1 et ${_currentOptions.length}.",
        );
      }
      return;
    }

    // ─── 5. Étape : awaiting action choice ───────────────────
    if (_stage == _ConversationStage.awaitingActionChoice) {
      final choice = _parseChoice(input);
      if (choice == 1) {
        await _launchNavigation();
        _stage = _ConversationStage.idle;
        await _addAIMessage("Quel autre medicament puis-je vous aider a trouver ?");
      } else if (choice == 2) {
        await _giveBasicAdvice();
        _stage = _ConversationStage.idle;
        await _addAIMessage("Puis-je faire autre chose pour vous ?");
      } else if (choice == 3) {
        _selectedOption = null;
        _currentOptions = [];
        _stage = _ConversationStage.idle;
        await _addAIMessage("Tres bien. Quel medicament recherchez-vous ?");
      } else {
        await _addAIMessage("Veuillez repondre par 1, 2 ou 3.");
      }
      return;
    }

    // ─── 6. Étape : idle — analyse de l'intention ────────────
    // 6a. Vérification hors-sujet (locale d'abord, IA ensuite)
    final isRelated = await _checkIsPharmacyRelated(input);
    if (!isRelated) {
      // Recadrage "pivot professionnel" (amélioration #3 du scénario)
      setState(() => _isProcessing = true);
      try {
        final pivotReply = await _geminiService.getOffTopicResponse(input);
        await _addAIMessage(pivotReply);
      } catch (_) {
        await _addAIMessage(
          "C'est une question interessante, on en parlera une autre fois ! "
          "Pour l'instant, ma priorite c'est votre sante. Comment puis-je vous aider ?",
        );
      } finally {
        setState(() => _isProcessing = false);
      }
      return;
    }

    // 6b. Description de symptômes → consultation avec empathie + questionnement
    if (_isSymptomDescription(input)) {
      await _startSymptomConsultation(input);
      return;
    }

    // 6c. Nom de médicament → recherche pharmacies proches
    await _searchMedication(input);
  }

  // ===========================================================
  // RECONNAISSANCE VOCALE
  // ===========================================================

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    await _flutterTts.stop();
    setState(() => _isListening = true);

    await _speechToText.listen(
      localeId: 'fr_FR',
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) async {
        final words = result.recognizedWords.trim();
        if (words.isEmpty || !result.finalResult) return;
        await _stopListening();
        await _handleInput(words);
      },
    );
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speechToText.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  // ===========================================================
  // PARSING NUMÉRIQUE
  // ===========================================================

  int? _parseChoice(String value) {
    final raw = value.trim().toLowerCase();

    final direct = int.tryParse(raw);
    if (direct != null) return direct;

    final match = RegExp(r'\b(\d+)\b').firstMatch(raw);
    if (match != null) return int.tryParse(match.group(1) ?? '');

    final words = <String, int>{
      'un': 1, 'une': 1,
      'deux': 2,
      'trois': 3,
      'quatre': 4,
      'cinq': 5,
    };
    for (final entry in words.entries) {
      if (raw.contains(entry.key)) return entry.value;
    }
    return null;
  }

  // ===========================================================
  // BUILD UI
  // ===========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("REBEC-DIN — Pharmacien Virtuel"),
        backgroundColor: AppColors.primary,
        actions: [
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau contextuel discret selon l'étape en cours
          if (_stage == _ConversationStage.awaitingAllergyInfo)
            _buildStageBanner(
              "Consultation en cours — Repondez aux deux questions ci-dessus",
              Colors.orange.shade50,
              Colors.orange,
            )
          else if (_stage == _ConversationStage.awaitingPharmacyChoice)
            _buildStageBanner(
              "Selectionnez une pharmacie (1 a ${_currentOptions.length})",
              Colors.green.shade50,
              Colors.green,
            )
          else if (_stage == _ConversationStage.awaitingActionChoice)
            _buildStageBanner(
              "Choisissez une action (1, 2 ou 3)",
              Colors.blue.shade50,
              Colors.blue,
            ),

          // Liste des messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
            ),
          ),

          // Barre de saisie
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildStageBanner(String text, Color bg, Color border) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: border),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12, color: border, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Bouton micro
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _isListening
                    ? Colors.red.shade50
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : AppColors.primary,
                ),
                onPressed: _speechAvailable && !_isProcessing
                    ? () async {
                        if (_isListening) {
                          await _stopListening();
                        } else {
                          await _startListening();
                        }
                      }
                    : null,
                tooltip: _isListening ? "Arreter l'ecoute" : "Parler",
              ),
            ),

            // Champ texte
            Expanded(
              child: TextField(
                controller: _inputController,
                enabled: !_isProcessing,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _isProcessing
                      ? "REBEC-DIN reflechit..."
                      : _stage == _ConversationStage.awaitingAllergyInfo
                          ? "Vos allergies et medicaments du jour..."
                          : "Symptomes, medicament ou question...",
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8),
                ),
                onSubmitted: _isProcessing ? null : _handleInput,
              ),
            ),

            // Bouton envoyer
            IconButton(
              icon: Icon(Icons.send_rounded, color: AppColors.primary),
              onPressed: _isProcessing
                  ? null
                  : () => _handleInput(_inputController.text),
              tooltip: "Envoyer",
            ),
          ],
        ),
      ),
    );
  }
}