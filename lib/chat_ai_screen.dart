import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/services/gemini_service.dart';
import 'package:pharma/services/whatsapp_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:pharma/theme/app_theme.dart';
import 'package:pharma/map/in_app_navigation_page.dart';

// ===========================================================
// ÉNUMÉRATIONS & MODÈLES INTERNES
// ===========================================================

enum _ConversationStage {
  idle,
  awaitingAllergyInfo,
  awaitingPharmacyChoice,
  awaitingWhatsAppReply,

  /// FIX #1: nouveau état — l'utilisateur a demandé des conseils directs
  /// sur un médicament sans passer par la recherche pharmacie.
  awaitingDirectAdviceConfirm,
}

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
  final DateTime timestamp;

  _ChatMessage({required this.text, required this.isUser})
    : timestamp = DateTime.now();

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

class _ChatAIScreenState extends State<ChatAIScreen>
    with TickerProviderStateMixin {
  // ---- Services ----
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final PharmacyService _pharmacyService = PharmacyService();
  final LocationService _locationService = LocationService();
  final GeminiService _geminiService = GeminiService();
  final WhatsAppService _whatsAppService = WhatsAppService();

  // ---- UI ----
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _typingAnimController;

  // ---- État conversation ----
  _ConversationStage _stage = _ConversationStage.idle;
  bool _isProcessing = false;

  // ---- Vocal ----
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _ttsEnabled = true;

  // ---- Données métier ----
  List<_PharmacyOption> _currentOptions = [];
  _PharmacyOption? _selectedOption;
  String? _lastMedicationQuery;
  int? _recommendedIndex;

  // --- Position utilisateur (dynamic pour compatibilité
  dynamic _userLocation;

  // ---- Consultation symptomatique ----
  _ConsultationData? _currentConsultation;

  // ---- Historique messages ----
  final List<_ChatMessage> _messages = [];

  /// FIX #2: Fenêtre de contexte agrandie à 10 messages (5 échanges complets)
  static const int _contextWindowSize = 10;

  // ===========================================================
  // CYCLE DE VIE
  // ===========================================================

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _initSpeech();
    _flutterTts.awaitSpeakCompletion(true);
    _configureTts();

    _addAIMessage(
      "Bonjour ! Je suis REBEC-DIN, votre pharmacien virtuel à Yaoundé.\n"
      "Comment vous sentez-vous aujourd'hui ? "
      "Décrivez vos symptômes, nommez le médicament que vous recherchez, "
      "ou demandez-moi des conseils (posologie, effets secondaires...).",
    );
  }

  @override
  void dispose() {
    _typingAnimController.dispose();
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
  // FIX #2 : CONTEXTE CONVERSATIONNEL ÉTENDU
  // - Fenêtre portée à 10 messages
  // - Contexte formaté avec horodatage pour meilleure cohérence
  // ===========================================================

  String _buildConversationContext() {
    final window = _messages.length > _contextWindowSize
        ? _messages.sublist(_messages.length - _contextWindowSize)
        : List<_ChatMessage>.from(_messages);
    return window.map((m) => '[${m.role}]: ${m.text}').join('\n---\n');
  }

  // ===========================================================
  // DÉTECTIONS LOCALES
  // ===========================================================

  bool _isGreeting(String value) {
    final raw = value.trim().toLowerCase();
    const greetings = [
      'bonjour',
      'salut',
      'bonsoir',
      'coucou',
      'hey',
      'hello',
      'hi',
      'salam',
    ];
    return greetings.contains(raw);
  }

  String _greetingReply(String value) {
    final raw = value.trim().toLowerCase();
    if (raw.contains('bonsoir')) {
      return "Bonsoir, comment puis-je vous aider ?";
    }

    final hour = DateTime.now().hour;
    final greeting = hour >= 18 ? 'Bonsoir' : 'Bonjour';
    return "$greeting, comment puis-je vous aider ?";
  }

  bool _isSymptomDescription(String value) {
    final lower = value.trim().toLowerCase();
    const keywords = [
      'fievre',
      'fièvre',
      'frisson',
      'mal',
      'douleur',
      'toux',
      'vomis',
      'diarrhee',
      'diarrhée',
      'fatigue',
      'faible',
      'fatigué',
      'pas bien',
      'malade',
      'grippe',
      'palu',
      'paludisme',
      'nausee',
      'nausée',
      'vertige',
      'maux',
      'brulure',
      'brûlure',
      'courbature',
      'transpire',
      'sueur',
      'essoufle',
      'essoufflé',
      'tete qui tourne',
      'pas me sentir',
      'me sens pas',
      'mal depuis',
      'depuis hier',
      'depuis ce matin',
      'migraine',
      'tete',
      'mal a la tete',
      'gorge',
      'ventre',
      'rhume',
      'nez bouche',
      'constipation',
      'ballonnement',
      'acidite',
    ];
    for (final k in keywords) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  bool _hasSeriousSymptoms(String value) {
    final lower = value.trim().toLowerCase();
    const keywords = [
      'convulsion',
      'confusion',
      'perte de connaissance',
      'evanoui',
      'difficulte a respirer',
      'respire mal',
      'douleur poitrine',
      'saignement abondant',
      'sang dans les selles',
      'vomit du sang',
      'vomissements repetes',
      'raideur de nuque',
      'paralysie',
      'faiblesse d un cote',
      'forte fievre',
      'fievre tres elevee',
      'grossesse',
      'enceinte',
      'bebe',
    ];
    for (final k in keywords) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  bool _isPharmacyLocationRequest(String value) {
    final lower = value.trim().toLowerCase();
    final hasLocation =
        lower.contains('pharmacie') ||
        lower.contains('officine') ||
        lower.contains('itineraire') ||
        lower.contains('route') ||
        lower.contains('ou trouver') ||
        lower.contains('où trouver');

    final hasProximity =
        lower.contains('proche') ||
        lower.contains('plus proche') ||
        lower.contains('autour') ||
        lower.contains('pres de') ||
        lower.contains('à cote') ||
        lower.contains('a cote') ||
        lower.contains('ou est') ||
        lower.contains('aller') ||
        lower.contains('où est') ||
        lower.contains('trouver');

    return hasLocation || hasProximity;
  }

  bool _isRouteOnlyRequest(String value) {
    final lower = value.trim().toLowerCase();
    return lower.contains('itineraire') ||
        lower.contains('route') ||
        lower.contains('guide moi') ||
        lower.contains('y aller') ||
        lower.contains('aller a la pharmacie');
  }

  /// FIX #1 : Détecte une demande de conseil direct (posologie, effets secondaires…)
  /// sans nécessité de trouver une pharmacie.
  bool _isMedicationAdviceRequest(String value) {
    final lower = value.trim().toLowerCase();
    const adviceKeywords = [
      'posologie',
      'dose',
      'dosage',
      'comment prendre',
      'comment utiliser',
      'effets secondaires',
      'effet secondaire',
      'effets indésirables',
      'contre-indication',
      'contre indication',
      'allergie à',
      'interaction',
      'à jeun',
      'avec repas',
      'overdose',
      'surdosage',
      'danger',
      'dangereux',
      'conseils',
      'conseil sur',
      'à quoi sert',
      'à quoi ca sert',
      'indication',
      'utilisation',
      'utiliser',
      'comment ça marche',
      'comment ca marche',
      'que fait',
      'information sur',
      'infos sur',
      'info sur',
      'peut on prendre',
      'puis je prendre',
      'puis-je prendre',
    ];
    for (final k in adviceKeywords) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  bool _isObviouslyOffTopic(String value) {
    final lower = value.trim().toLowerCase();
    const keywords = [
      'football',
      'sport',
      'musique',
      'politique',
      'meteo',
      'météo',
      'recette',
      'cuisine',
      'cinema',
      'cinéma',
      'film',
      'serie',
      'série',
      'gaming',
      'jeu video',
      'informatique',
      'programmation',
      'codage',
      'crypto',
      'bitcoin',
      'framework',
      'javascript',
      'python',
      'base de donnees',
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
  // CONSULTATION SYMPTOMATIQUE
  // ===========================================================

  Future<void> _startSymptomConsultation(String symptoms) async {
    _currentConsultation = _ConsultationData(symptoms: symptoms);
    _lastMedicationQuery = symptoms;

    setState(() => _stage = _ConversationStage.awaitingAllergyInfo);
  }

  Future<void> _handleAllergyResponse(String response) async {
    if (_currentConsultation == null) {
      setState(() => _stage = _ConversationStage.idle);
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

      await _addAIMessage(
        "Si vous souhaitez que je vous localise une pharmacie ou un laboratoire "
        "proche pour faire votre test, dites-moi : "
        "\"Où est la pharmacie la plus proche ?\"",
      );
    } catch (_) {
      await _addAIMessage(
        "Je n'ai pas pu traiter votre consultation. "
        "Veuillez vous rendre directement chez un professionnel de santé.",
      );
    } finally {
      setState(() {
        _isProcessing = false;
        _stage = _ConversationStage.idle;
      });
      _currentConsultation = null;
    }
  }

  // ===========================================================
  // FIX #1 : CONSEILS DIRECTS SUR UN MÉDICAMENT
  // Route directe : demande conseil → Gemini → réponse immédiate
  // Anciennement, cette logique n'était accessible qu'après sélection
  // d'une pharmacie (choix n°2 du menu action).
  // ===========================================================

  Future<void> _handleDirectAdviceRequest(String userInput) async {
    // Mémoriser le médicament pour usage ultérieur (ex: choix "2" du menu)
    _lastMedicationQuery = userInput;
    setState(() => _isProcessing = true);

    try {
      final context = _buildConversationContext();
      final advice = await _geminiService.getMedicationAdvice(
        userInput,
        context: context,
      );
      await _addAIMessage(advice);
      // Proposer de trouver une pharmacie APRÈS les conseils
      await _addAIMessage(
        "Souhaitez-vous que je vous localise une pharmacie proche "
        "pour trouver ce médicament ? Tapez \"pharmacie proche\" ou posez-moi une autre question.",
      );
    } catch (_) {
      await _addAIMessage(
        "Je n'ai pas pu récupérer les conseils. "
        "Veuillez réessayer ou consulter directement un pharmacien.",
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ===========================================================
  // RECHERCHE PHARMACIE — LOCALISATION SEULE
  // ===========================================================

  Future<void> _searchNearestPharmacy() async {
    setState(() => _isProcessing = true);

    await _addAIMessage(
      "🔍 Je recherche les officines autour de vous à Yaoundé...",
    );

    final location = await _locationService.tryGetCurrentPosition();
    if (location == null) {
      setState(() => _isProcessing = false);
      await _addAIMessage(
        "Je n'arrive pas à accéder à votre position. "
        "Veuillez activer la localisation et réessayer.",
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
        "Aucune pharmacie trouvée à proximité pour le moment. Réessayez dans quelques instants.",
      );
      return;
    }

    final options =
        pharmacies.map((pharmacy) {
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
        }).toList()..sort(
          (a, b) => (a.distanceMeters ?? 999999).compareTo(
            b.distanceMeters ?? 999999,
          ),
        );

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
      if (min != null) {
        buf.writeln(
          "⭐ La plus rapide : ${rec.pharmacy.nom} "
          "(~$min minute${min > 1 ? 's' : ''} en voiture)\n",
        );
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

    buf.write(
      "\nTapez le numéro pour ouvrir l'itinéraire de la pharmacie choisie.",
    );

    await _addAIMessage(buf.toString());
    setState(() => _stage = _ConversationStage.awaitingPharmacyChoice);
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
        "Je n'arrive pas à accéder à votre position. "
        "Veuillez activer la localisation puis réessayez.",
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
        "Je ne trouve aucune pharmacie proche pour le moment. Réessayez dans quelques instants.",
      );
      return;
    }

    final options =
        pharmacies.map((pharmacy) {
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
        }).toList()..sort(
          (a, b) => (a.distanceMeters ?? 999999).compareTo(
            b.distanceMeters ?? 999999,
          ),
        );

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
      "Voici les pharmacies en ligne enregistrees depuis Pharm Admin "
      "pour $medicationName :\n",
    );

    if (_recommendedIndex != null) {
      final rec = _currentOptions[_recommendedIndex!];
      final s = travelTimesSeconds[_recommendedIndex!];
      final min = s == null ? null : (s / 60).round();
      final label = min == null
          ? "la plus proche"
          : "la plus rapide (~$min min de trajet)";
      buf.writeln(
        "⭐ Recommandation REBEC-DIN : ${rec.pharmacy.nom} ($label)\n",
      );
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

    buf.write(
      "\nDites ou tapez le numéro de la pharmacie souhaitée pour ouvrir l'itinéraire.",
    );

    await _addAIMessage(buf.toString());
    setState(() => _stage = _ConversationStage.awaitingPharmacyChoice);
  }

  // ===========================================================
  // ACTIONS SUR LA PHARMACIE SÉLECTIONNÉE
  // ===========================================================

  Future<void> _launchNavigation() async {
    final pharmacy = _selectedOption?.pharmacy;
    if (pharmacy == null) {
      await _addAIMessage("Veuillez d'abord choisir une pharmacie.");
      return;
    }

    setState(() => _isProcessing = true);

    // Obtenir position utilisateur via le service (compatible GeoPoint/Map)
    final dynamic location = await _locationService.tryGetCurrentPosition();
    if (location == null) {
      setState(() => _isProcessing = false);
      await _addAIMessage(
        "Position utilisateur introuvable. Activez la localisation et réessayez.",
      );
      return;
    }

    double startLat = 0.0;
    double startLng = 0.0;

    try {
      final a = (location as dynamic).latitude;
      final b = (location as dynamic).longitude;
      if (a is num) startLat = a.toDouble();
      if (b is num) startLng = b.toDouble();
    } catch (_) {}
    if (startLat == 0.0 && startLng == 0.0) {
      try {
        final a = (location as dynamic)['latitude'];
        final b = (location as dynamic)['longitude'];
        if (a is num) startLat = a.toDouble();
        if (b is num) startLng = b.toDouble();
      } catch (_) {}
    }

    // final destLat = Pharmacy.extractLat((pharmacy as dynamic).localisation);
    // final destLng = Pharmacy.extractLng((pharmacy as dynamic).localisation);

    // Extraire les coordonnées de la pharmacie de façon robuste
    final dynamic loc = (pharmacy as dynamic).localisation;
    double destLat = 0.0;
    double destLng = 0.0;
    if (loc != null) {
      try {
        final a = (loc as dynamic).latitude;
        final b = (loc as dynamic).longitude;
        if (a is num) destLat = a.toDouble();
        if (b is num) destLng = b.toDouble();
      } catch (_) {}
      if (destLat == 0.0 && destLng == 0.0) {
        try {
          final a = loc['latitude'] ?? loc['lat'];
          final b = loc['longitude'] ?? loc['lng'] ?? loc['lon'];
          if (a is num) destLat = a.toDouble();
          if (b is num) destLng = b.toDouble();
        } catch (_) {}
      }
    }

    if (destLat == 0.0 || destLng == 0.0) {
      setState(() => _isProcessing = false);
      await _addAIMessage("Coordonnées de la pharmacie indisponibles.");
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InAppNavigationPage(
          startLat: startLat,
          startLng: startLng,
          destLat: destLat,
          destLng: destLng,
          pharmacyName: (pharmacy as dynamic).nom?.toString() ?? '',
        ),
      ),
    );

    setState(() => _isProcessing = false);
    await _addAIMessage(
      "Itinéraire ouvert dans l'application vers ${(pharmacy as dynamic).nom}.",
    );
  }

  String? _primaryWhatsAppNumber(Pharmacy pharmacy) {
    final whatsapp = pharmacy.whatsapp?.trim();
    if (whatsapp != null && whatsapp.isNotEmpty) {
      return whatsapp;
    }
    final phone = pharmacy.telephone?.trim();
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return null;
  }

  Future<void> _launchPhoneCall() async {
    final pharmacy = _selectedOption?.pharmacy;
    final phone = pharmacy?.telephone?.trim();
    if (pharmacy == null || phone == null || phone.isEmpty) {
      await _addAIMessage(
        "Le numero de telephone de cette pharmacie est indisponible.",
      );
      return;
    }

    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (launched) {
      await _addAIMessage("Appel lance vers ${pharmacy.nom}.");
    } else {
      await _addAIMessage("Impossible de lancer l'appel pour le moment.");
    }
  }

  Future<void> _launchWhatsAppAvailabilityRequest() async {
    final pharmacy = _selectedOption?.pharmacy;
    if (pharmacy == null) {
      await _addAIMessage("Veuillez d'abord choisir une pharmacie.");
      return;
    }

    final phone = _primaryWhatsAppNumber(pharmacy);
    if (phone == null) {
      await _addAIMessage(
        "Le contact WhatsApp de cette pharmacie est indisponible.",
      );
      return;
    }

    final medication = _lastMedicationQuery?.trim().isNotEmpty == true
        ? _lastMedicationQuery!.trim()
        : 'le medicament recherche';

    final launched = await _whatsAppService.openAvailabilityRequest(
      phoneNumber: phone,
      pharmacyName: pharmacy.nom,
      medicationName: medication,
    );

    if (!launched) {
      await _addAIMessage("Impossible d'ouvrir WhatsApp pour le moment.");
      return;
    }

    await _addAIMessage(
      "J'ai ouvert WhatsApp avec un message pret a envoyer a ${pharmacy.nom}. "
      "Quand la pharmacie repond, copiez sa reponse ici et je l'interpreterai.",
    );
    setState(() => _stage = _ConversationStage.awaitingWhatsAppReply);
  }

  Future<void> _interpretWhatsAppReply(String reply) async {
    final pharmacy = _selectedOption?.pharmacy;
    final medication = _lastMedicationQuery?.trim().isNotEmpty == true
        ? _lastMedicationQuery!.trim()
        : 'le medicament recherche';

    if (pharmacy == null) {
      setState(() => _stage = _ConversationStage.idle);
      await _addAIMessage(
        "Je n'ai plus la pharmacie selectionnee. Relancez la recherche.",
      );
      return;
    }

    final interpretation = _whatsAppService.interpretPharmacyReply(
      reply,
      pharmacyName: pharmacy.nom,
      medicationName: medication,
    );

    await _addAIMessage(interpretation.summary);
    setState(() => _stage = _ConversationStage.idle);
    await _addAIMessage(
      "Vous pouvez rechercher un autre medicament si besoin.",
    );
  }

  Future<void> _giveBasicAdvice() async {
    final medication = _lastMedicationQuery;

    // Si le médicament est inconnu : demander son nom et attendre
    if (medication == null || medication.trim().isEmpty) {
      await _addAIMessage(
        "Pour vous donner des conseils précis, quel médicament souhaitez-vous ? "
        "Tapez son nom et je vous fournirai posologie, effets secondaires et précautions.",
      );
      setState(() => _stage = _ConversationStage.awaitingDirectAdviceConfirm);
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final context = _buildConversationContext();
      final advice = await _geminiService.getMedicationAdvice(
        medication,
        context: context,
      );
      await _addAIMessage(advice);
      // Message de suivi ici — APRÈS la réponse Gemini, pas en parallèle
      await _addAIMessage("Puis-je faire autre chose pour vous ?");
    } catch (_) {
      await _addAIMessage(
        "Je n'ai pas pu récupérer les conseils. "
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
    if (_ttsEnabled) {
      await _flutterTts.speak(text);
    }
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

    if (_stage == _ConversationStage.awaitingWhatsAppReply) {
      await _interpretWhatsAppReply(input);
      return;
    }

    // ─── 1. Salutation ───────────────────────────────────────
    if (_isGreeting(input)) {
      await _addAIMessage(_greetingReply(input));
      return;
    }

    // ─── 2. Demande de localisation pharmacie ────────────────
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
        setState(() => _stage = _ConversationStage.idle);
        await _launchNavigation();
      } else {
        await _addAIMessage(
          "Je n'ai pas compris. Veuillez dire un numéro entre 1 et ${_currentOptions.length}.",
        );
      }
      return;
    }

    // ─── 4b. Étape : awaiting direct advice confirm ──────────
    // L'utilisateur vient de taper le nom du médicament qu'on lui a demandé
    if (_stage == _ConversationStage.awaitingDirectAdviceConfirm) {
      _lastMedicationQuery = input;
      setState(() => _stage = _ConversationStage.idle);
      await _handleDirectAdviceRequest(input);
      return;
    }

    // ─── 5. Étape : awaiting action choice ───────────────────
    // (Supprimé : la sélection du numéro ouvre maintenant directement l'itinéraire)

    // ─── 6. Étape : idle — analyse de l'intention ────────────

    // 6a. Vérification hors-sujet
    final isRelated = await _checkIsPharmacyRelated(input);
    if (!isRelated) {
      setState(() => _isProcessing = true);
      try {
        final pivotReply = await _geminiService.getOffTopicResponse(input);
        await _addAIMessage(pivotReply);
      } catch (_) {
        await _addAIMessage(
          "C'est une question intéressante, on en parlera une autre fois ! "
          "Pour l'instant, ma priorité c'est votre santé. Comment puis-je vous aider ?",
        );
      } finally {
        setState(() => _isProcessing = false);
      }
      return;
    }

    // 6b. Description de symptômes
    if (_isSymptomDescription(input)) {
      if (_hasSeriousSymptoms(input)) {
        await _addAIMessage(
          "Vos symptomes peuvent etre serieux. Je vous conseille de consulter rapidement un medecin "
          "ou de vous rendre aux urgences, surtout si cela s'aggrave, dure longtemps, ou concerne un enfant, "
          "une femme enceinte ou une personne fragile.",
        );
        return;
      }
      await _startSymptomConsultation(input);
      return;
    }

    // FIX #1 : 6c. Demande directe de conseils médicament
    // AVANT la recherche de pharmacie → route dédiée sans passer par OSM
    if (_isMedicationAdviceRequest(input)) {
      await _handleDirectAdviceRequest(input);
      return;
    }

    // 6d. Nom de médicament → recherche pharmacies proches
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

    const words = <String, int>{
      'un': 1,
      'une': 1,
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
  // FIX #3 : BUILD UI — DESIGN PRO REFONDU
  // Améliorations :
  //  - AppBar avec dégradé + sous-titre statut
  //  - Avatar IA avec initiales et couleur distinctive
  //  - Bulles de message avec typographie soignée + timestamp discret
  //  - Indicateur "frappe en cours" animé (3 points)
  //  - Barre de saisie avec fond distinct et coins arrondis
  //  - Bannières de contexte pill-shaped
  // ===========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          _buildAppBar(),

          // Bandeau contextuel
          if (_stage == _ConversationStage.awaitingAllergyInfo)
            _buildContextPill(
              "Consultation en cours — répondez aux deux questions",
              const Color(0xFFFFF3E0),
              const Color(0xFFF57C00),
              Icons.healing_outlined,
            )
          else if (_stage == _ConversationStage.awaitingPharmacyChoice)
            _buildContextPill(
              "Sélectionnez une pharmacie (1 à ${_currentOptions.length})",
              const Color(0xFFE8F5E9),
              const Color(0xFF388E3C),
              Icons.local_pharmacy_outlined,
            )
          else if (_stage == _ConversationStage.awaitingWhatsAppReply)
            _buildContextPill(
              "Collez ici la reponse WhatsApp de la pharmacie",
              const Color(0xFFE8F5E9),
              const Color(0xFF128C7E),
              Icons.chat_outlined,
            ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length && _isProcessing) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[i]);
              },
            ),
          ),

          _buildInputBar(),
        ],
      ),
    );
  }

  // ---- AppBar personnalisée ----
  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF00695C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x3300695C),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar IA
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Text(
                    "R",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "REBEC-DIN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF69F0AE),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          _isProcessing
                              ? "En train de répondre..."
                              : "Pharmacien Virtuel • Yaoundé",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_isProcessing)
                IconButton(
                  icon: Icon(
                    _ttsEnabled ? Icons.volume_up : Icons.volume_off,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: _ttsEnabled ? 'Désactiver voix' : 'Activer voix',
                  onPressed: () async {
                    setState(() => _ttsEnabled = !_ttsEnabled);
                    if (!_ttsEnabled) {
                      await _flutterTts.stop();
                    }
                  },
                ),
              if (_isProcessing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Bannière de contexte ----
  Widget _buildContextPill(String text, Color bg, Color accent, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Bulle de message ----
  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    final time =
        "${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // Avatar IA (uniquement pour les messages de l'IA)
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00897B), Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  "R",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],

          // Bulle + horodatage
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xFF00897B) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFF1A1A2E),
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Espace pour aligner les messages utilisateur
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ---- Indicateur de frappe animé ----
  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF004D40)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                "R",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _typingAnimController,
              builder: (_, __) {
                return Row(
                  children: List.generate(3, (i) {
                    final delay = i * 0.2;
                    final value = (_typingAnimController.value - delay).clamp(
                      0.0,
                      1.0,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.translate(
                        offset: Offset(0, -4 * value),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              Colors.grey.shade300,
                              const Color(0xFF00897B),
                              value,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---- Barre de saisie ----
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, -3),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isListening
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFF0FAF8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none_rounded,
                  color: _isListening
                      ? const Color(0xFFE53935)
                      : const Color(0xFF00897B),
                  size: 22,
                ),
                onPressed: _speechAvailable && !_isProcessing
                    ? () async {
                        _isListening
                            ? await _stopListening()
                            : await _startListening();
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 8),

            // Champ texte
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: TextField(
                  controller: _inputController,
                  enabled: !_isProcessing,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: _isProcessing
                        ? "REBEC-DIN réfléchit..."
                        : _stage == _ConversationStage.awaitingAllergyInfo
                        ? "Vos allergies et médicaments du jour..."
                        : _stage == _ConversationStage.awaitingWhatsAppReply
                        ? "Collez la reponse WhatsApp..."
                        : "Symptômes, médicament, posologie...",
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onSubmitted: _isProcessing ? null : _handleInput,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton envoyer
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00BFA5), Color(0xFF00897B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _isProcessing
                    ? null
                    : () => _handleInput(_inputController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
