import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/services/pharmacy_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:pharma/theme/app_theme.dart';

enum _ConversationStage {
  idle,
  awaitingPharmacyChoice,
  awaitingActionChoice,
}

class _PharmacyOption {
  const _PharmacyOption({
    required this.pharmacy,
    this.distanceMeters,
  });

  final Pharmacy pharmacy;
  final double? distanceMeters;
}

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final PharmacyService _pharmacyService = PharmacyService();
  final LocationService _locationService = LocationService();
  final TextEditingController _controller = TextEditingController();

  _ConversationStage _stage = _ConversationStage.idle;

  bool _speechAvailable = false;
  bool _isListening = false;

  List<_PharmacyOption> _currentOptions = [];
  _PharmacyOption? _selectedOption;
  final List<_ChatMessage> _messages = [];

  String? _lastMedicationQuery;
  int? _recommendedIndex;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _flutterTts.awaitSpeakCompletion(true);
    _configureTts();
    _addAIMessage(
      "Bonjour, je suis REBEC-DIN, votre pharmacien virtuel.\nQuel médicament recherchez-vous ?",
    );
  }

  Future<void> _initSpeech() async {
    final available = await _speechToText.initialize();
    if (!mounted) return;
    setState(() {
      _speechAvailable = available;
    });
  }

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage('fr-FR');
    await _flutterTts.setSpeechRate(0.48);
    await _flutterTts.setPitch(1.0);

    final voices = await _flutterTts.getVoices;
    if (voices is List) {
      Map? chosen;
      for (final v in voices) {
        if (v is Map) {
          final locale = (v['locale'] ?? v['language'] ?? '').toString();
          if (locale.toLowerCase().startsWith('fr')) {
            chosen = v;
            break;
          }
        }
      }
      if (chosen != null) {
        await _flutterTts.setVoice(Map<String, String>.from(chosen));
      }
    }
  }

  Future<String> _askGeminiAdvice(String medication) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return "Je ne peux pas donner de conseils pour le moment (clé API manquante).";
    }

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey';

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    "Tu es un pharmacien professionnel. Tu t'appelles REBEC-DIN. "
                        "Tu réponds en français uniquement. "
                        "Donne des conseils de base, précautions et contre-indications générales, "
                        "et rappelle de demander l'avis d'un médecin ou pharmacien en cas de doute. "
                        "Ne mentionne pas de dosage personnalisé. "
                        "Médicament : $medication"
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        return "Je n'ai pas pu générer de conseils pour le moment.";
      }
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = parts != null && parts.isNotEmpty ? parts.first['text'] : null;
      return (text ?? "Je n'ai pas pu générer de conseils.").toString();
    }

    return "Je n'ai pas pu récupérer les conseils (erreur réseau).";
  }

  bool _isGreeting(String value) {
    final raw = value.trim().toLowerCase();
    return raw == 'bonjour' ||
        raw == 'salut' ||
        raw == 'bonsoir' ||
        raw == 'coucou' ||
        raw == 'hey' ||
        raw == 'hello';
  }

  bool _isClearlyOffTopic(String value) {
    final raw = value.trim().toLowerCase();
    const offTopic = {
      'patate',
      'pomme de terre',
      'football',
      'météo',
      'musique',
      'politique',
      'argent',
      'jeu',
      'gaming',
    };
    for (final k in offTopic) {
      if (raw.contains(k)) return true;
    }
    return false;
  }

  // ==========================
  // RECHERCHE MEDICAMENT
  // ==========================
  Future<void> _searchMedication(String medicationName) async {
    await _addUserMessage(medicationName);

    _lastMedicationQuery = medicationName;
    _recommendedIndex = null;

    final location = await _locationService.tryGetCurrentPosition();
    if (location == null) {
      await _addAIMessage(
        "Je n'arrive pas à accéder à votre position. Activez la localisation puis réessayez.",
      );
      return;
    }

    final pharmacies = await _pharmacyService.fetchNearbyPharmacies(
      latitude: location.latitude,
      longitude: location.longitude,
    );

    if (pharmacies.isEmpty) {
      await _addAIMessage(
        "Je ne trouve aucune pharmacie proche pour le moment. Réessayez dans quelques secondes.",
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
      ..sort(
        (a, b) =>
            (a.distanceMeters ?? 999999).compareTo(b.distanceMeters ?? 999999),
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
      final seconds = travelTimesSeconds[i];
      if (seconds == null) continue;
      if (bestSeconds == null || seconds < bestSeconds) {
        bestSeconds = seconds;
        bestIndex = i;
      }
    }
    _recommendedIndex = bestIndex ?? 0;

    String response =
        "Je ne peux pas vérifier le stock du médicament en ligne, mais je peux vous indiquer les pharmacies les plus proches pour vous y rendre.\n\n";

    if (_recommendedIndex != null && _recommendedIndex! >= 0) {
      final recommended = _currentOptions[_recommendedIndex!];
      final seconds = travelTimesSeconds[_recommendedIndex!];
      final minutes = seconds == null ? null : (seconds / 60).round();
      final label = minutes == null
          ? "la plus proche"
          : "la plus rapide selon un temps de trajet estimé (~${minutes} min)";
      response +=
          "Recommandation REBEC-DIN : ${recommended.pharmacy.nom} ($label).\n\n";
    }

    response +=
        "Voici les 5 pharmacies les plus proches :\n\n";

    for (int i = 0; i < _currentOptions.length; i++) {
      final option = _currentOptions[i];
      final km = option.distanceMeters == null
          ? null
          : (option.distanceMeters! / 1000);
      final distanceLabel = km == null
          ? ""
          : " (${km.toStringAsFixed(2)} km)";

      final seconds = travelTimesSeconds[i];
      final minutes = seconds == null ? null : (seconds / 60).round();
      final trafficLabel = minutes == null ? "" : " - ~${minutes} min";

      response += "${i + 1}. ${option.pharmacy.nom}$distanceLabel\n";
      if (trafficLabel.isNotEmpty) {
        response += "   $trafficLabel\n";
      }
    }

    response += "\nDites ou entrez le numéro de la pharmacie.";

    await _addAIMessage(response);
    _stage = _ConversationStage.awaitingPharmacyChoice;
  }

  // ==========================
  // NAVIGATION
  // ==========================
  Future<void> _launchNavigation() async {
    if (_selectedOption == null) return;

    final point = _selectedOption!.pharmacy.localisation;
    if (point == null) return;

    final url = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}&travelmode=driving");

    await launchUrl(url, mode: LaunchMode.externalApplication);

    await _addAIMessage(
        "Itinéraire lancé vers ${_selectedOption!.pharmacy.nom}.");
  }

  Future<void> _giveBasicAdvice() async {
    final medication = _lastMedicationQuery;
    if (medication == null || medication.trim().isEmpty) {
      await _addAIMessage("Dites-moi d'abord le nom du médicament.");
      return;
    }

    await _addAIMessage("Très bien. Je vous donne des conseils de base pour $medication.");
    final advice = await _askGeminiAdvice(medication);
    await _addAIMessage(advice);
  }

  // ==========================
  // MESSAGE HELPERS
  // ==========================
  Future<void> _addAIMessage(String text) async {
    if (_isListening) {
      await _stopListening();
    }
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false));
    });
    await _flutterTts.speak(text);
  }

  Future<void> _addUserMessage(String text) async {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
    });
  }

  // ==========================
  // UI
  // ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Assistant IA Pharmacie"),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color:
                            msg.isUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  onPressed: _speechAvailable
                      ? () async {
                          if (_isListening) {
                            await _stopListening();
                          } else {
                            await _startListening();
                          }
                        }
                      : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Entrez un médicament...",
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) async {
                      await _handleInput(value);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    await _handleInput(_controller.text);
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    await _flutterTts.stop();

    setState(() {
      _isListening = true;
    });

    await _speechToText.listen(
      localeId: 'fr_FR',
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) async {
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;
        if (result.finalResult) {
          await _stopListening();
          await _handleInput(words);
        }
      },
    );
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;
    await _speechToText.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });
  }

  int? _parseChoice(String value) {
    final raw = value.trim().toLowerCase();

    final direct = int.tryParse(raw);
    if (direct != null) return direct;

    final digitMatch = RegExp(r'\b(\d+)\b').firstMatch(raw);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1) ?? '');
    }

    const map = {
      'un': 1,
      'une': 1,
      'deux': 2,
      'trois': 3,
      'quatre': 4,
      'cinq': 5,
    };
    for (final entry in map.entries) {
      if (raw.contains(entry.key)) return entry.value;
    }
    return null;
  }

  Future<void> _handleInput(String value) async {
    if (value.isEmpty) return;

    _controller.clear();

    if (_isGreeting(value)) {
      await _addAIMessage(
        "Bonjour ! Je suis REBEC-DIN. Dites-moi le nom d'un médicament, et je vous propose les pharmacies les plus proches.",
      );
      return;
    }

    if (_isClearlyOffTopic(value)) {
      await _addAIMessage(
        "Je suis REBEC-DIN, et je reste dans le domaine pharmacie/médicaments. Dites-moi plutôt le nom d'un médicament, un symptôme, ou demandez-moi une pharmacie proche.",
      );
      return;
    }

    if (_stage == _ConversationStage.idle) {
      await _searchMedication(value);
    } else if (_stage == _ConversationStage.awaitingPharmacyChoice) {
      final index = _parseChoice(value);
      if (index != null &&
          index > 0 &&
          index <= _currentOptions.length) {
        _selectedOption = _currentOptions[index - 1];

        await _addAIMessage(
          "Que souhaitez-vous faire ?\n1. Lancer l'itinéraire\n2. Conseils de base sur le médicament\n3. Rechercher un autre médicament",
        );
        _stage = _ConversationStage.awaitingActionChoice;
      } else {
        await _addAIMessage("Je n'ai pas compris. Dites un numéro entre 1 et ${_currentOptions.length}.");
      }
    } else if (_stage == _ConversationStage.awaitingActionChoice) {
      final choice = _parseChoice(value);
      if (choice == 1) {
        await _launchNavigation();
        _stage = _ConversationStage.idle;
      } else if (choice == 2) {
        await _giveBasicAdvice();
        _stage = _ConversationStage.idle;
      } else if (choice == 3) {
        _selectedOption = null;
        _currentOptions = [];
        _stage = _ConversationStage.idle;
        await _addAIMessage("Très bien. Quel médicament recherchez-vous ?");
      } else {
        await _addAIMessage("Dites 1, 2 ou 3.");
      }
    }
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}