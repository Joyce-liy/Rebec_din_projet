import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  static const Duration _timeout = Duration(seconds: 30);

  final String? _apiKey;

  GeminiService() : _apiKey = dotenv.env['GEMINI_API_KEY'];

  // Singleton pour l'appel statique depuis scanner_page.dart
  static final GeminiService _instance = GeminiService();

  bool get isAvailable => _apiKey?.isNotEmpty ?? false;

  // =========================================================
  // WRAPPER STATIQUE — scanner_page.dart
  // =========================================================

  static Future<List<String>> readHandwrittenPrescription(
      Uint8List imageBytes) async {
    return _instance._readHandwrittenPrescriptionImpl(imageBytes);
  }

  // =========================================================
  // NOUVEAU : DÉTECTION DU TYPE D'ENTRÉE
  // =========================================================

  /// Retourne : 'SYMPTOMES' | 'MEDICAMENT' | 'PHARMACIE' | 'SALUTATION' | 'HORS_SUJET'
  Future<String> detectInputType(String userInput) async {
    if (!isAvailable) return 'MEDICAMENT';

    try {
      final response = await _callGemini(
        systemPrompt: """Classifie le message en UNE SEULE catégorie :
- SYMPTOMES : l'utilisateur décrit comment il se sent (fièvre, douleur, frissons, malaise, fatigue, etc.)
- MEDICAMENT : l'utilisateur demande un médicament spécifique par son nom
- PHARMACIE : l'utilisateur cherche une pharmacie, officine ou demande où trouver des médicaments
- SALUTATION : simple salutation (bonjour, bonsoir, etc.)
- HORS_SUJET : sujet sans rapport avec la santé ou la pharmacie

Réponds UNIQUEMENT avec le mot catégorie, sans rien d'autre.""",
        userMessage: userInput,
      ).timeout(_timeout);

      final text = _extractText(response).trim().toUpperCase();
      if (text.contains('SYMPTOMES')) return 'SYMPTOMES';
      if (text.contains('PHARMACIE')) return 'PHARMACIE';
      if (text.contains('SALUTATION')) return 'SALUTATION';
      if (text.contains('HORS_SUJET')) return 'HORS_SUJET';
      return 'MEDICAMENT';
    } catch (_) {
      return 'MEDICAMENT';
    }
  }

  // =========================================================
  // NOUVEAU : CONSULTATION SYMPTOMATIQUE (scénario paludisme/grippe)
  // =========================================================

  /// Consultation empathique basée sur les symptômes décrits.
  /// Respecte : empathie → questionnement → diagnostic avant traitement → orientation.
  Future<String> conductSymptomConsultation(
    String symptoms, {
    String? allergyAndMedsInfo,
    String? context,
  }) async {
    if (!isAvailable) {
      return "Je comprends que vous ne vous sentez pas bien. "
          "Avant tout traitement, je vous recommande vivement de faire un test "
          "en laboratoire pour confirmer le diagnostic. "
          "Avez-vous des allergies connues à des médicaments ?";
    }

    final patientInfo = (allergyAndMedsInfo?.isNotEmpty ?? false)
        ? "Informations déclarées par le patient : $allergyAndMedsInfo"
        : "Allergies et médicaments du jour : non renseignés";

    final contextInfo = (context?.isNotEmpty ?? false)
        ? "\nHistorique récent :\n$context"
        : "";

    try {
      final response = await _callGemini(
        systemPrompt: """Tu es REBEC-DIN, pharmacien expert à Yaoundé, Cameroun, avec 15 ans d'expérience clinique.
Un patient vient te voir en décrivant des symptômes. Voici comment tu dois répondre :

ÉTAPE 1 — EMPATHIE (1 phrase) :
Reconnais sincèrement l'état du patient. Exemple : "Je suis désolé de vous voir dans cet état, mais vous avez bien fait de venir."

ÉTAPE 2 — ANALYSE CLINIQUE :
- Identifie les symptômes possibles dans le contexte camerounais (paludisme, grippe, typhoïde, etc.)
- Si les symptômes évoquent le paludisme (fièvre + frissons) : EXIGE un TDR ou une goutte épaisse avant tout antipaludique
- Explique POURQUOI ce test est important (éviter de fatiguer le foie inutilement, résistances aux traitements)

ÉTAPE 3 — CONSEILS IMMÉDIATS SÛRS :
- Hydratation abondante
- Repos
- Antipyrétique si fièvre — MAIS vérifie d'abord qu'il n'a pas déjà atteint la dose max de Paracétamol (4g/jour)

ÉTAPE 4 — SIGNES D'ALARME :
Mentionne les signes qui nécessitent l'hôpital en urgence (convulsions, vomissements répétés, confusion, fièvre très élevée).

ÉTAPE 5 — ORIENTATION :
Encourage à passer au laboratoire AVANT de revenir chercher le traitement.

RÈGLES ABSOLUES :
- Jamais de dosage personnalisé
- Toujours recommander un professionnel de santé pour confirmation
- Ton chaleureux, pédagogue, professionnel — pas de jargon inutile
- Français uniquement, 250 mots maximum

$patientInfo$contextInfo""",
        userMessage:
            "Le patient décrit les symptômes suivants : $symptoms",
      ).timeout(_timeout);

      return _extractText(response);
    } catch (_) {
      return "Je vous entends et je comprends votre inconfort. "
          "Ces symptômes méritent une attention sérieuse. "
          "Avant tout traitement, je vous recommande de passer au laboratoire "
          "pour un test de confirmation. "
          "En attendant, hydratez-vous bien et reposez-vous. "
          "Si la situation s'aggrave rapidement, rendez-vous directement à l'hôpital.";
    }
  }

  // =========================================================
  // MÉTHODES EXISTANTES — PROMPTS AMÉLIORÉS
  // =========================================================

  /// Détecte si la requête est liée à la pharmacie/santé
  Future<bool> isPharmacyRelated(String userInput) async {
    if (!isAvailable) return true;

    try {
      final response = await _callGemini(
        systemPrompt: """Tu es un classifier pour un assistant pharmacien à Yaoundé.
Détermine si la requête est liée à la santé, pharmacie, médicaments, symptômes ou bien-être.
Réponds UNIQUEMENT "OUI" ou "NON".""",
        userMessage: userInput,
      ).timeout(_timeout);

      return _extractText(response).toUpperCase().contains('OUI');
    } catch (_) {
      return true;
    }
  }

  /// Réponse de recadrage "pivot professionnel" — technique en 3 temps
  Future<String> getOffTopicResponse(String userInput) async {
    if (!isAvailable) {
      return "C'est une question intéressante, on en parlera une autre fois ! "
          "Pour l'instant, ma priorité c'est votre santé. "
          "Comment puis-je vous aider ?";
    }

    try {
      final response = await _callGemini(
        systemPrompt: """Tu es REBEC-DIN, pharmacien expert à Yaoundé, Cameroun.
L'utilisateur t'a posé une question hors de ton domaine (non médicale).

Applique la technique du PIVOT PROFESSIONNEL en exactement 3 temps :

1. VALIDE brièvement et avec humour bienveillant (ex: "C'est gentil de partager ça !", "Quelle curiosité !")
2. POSE UNE LIMITE légère (ex: "On pourra en discuter une autre fois autour d'un café", "Ce n'est pas vraiment mon rayon aujourd'hui")
3. TRANSITION vers la santé (ex: "Mais ma priorité pour l'instant, c'est votre santé", "Revenons à ce qui vous a amené ici")

Exemples de bon recadrage :
- Si l'utilisateur parle d'informatique : "C'est gentil de vous intéresser à nos outils ! On en parlera peut-être autour d'un café. Mais pour l'instant, ma priorité, c'est votre santé. Comment puis-je vous aider ?"
- Si l'utilisateur parle de football : "Un grand fan, je vois ! Ce débat passionnant mérite une autre occasion. Pour l'instant, revenons à ce qui vous a amené ici."

Ton : chaleureux, jamais condescendant, maximum 2-3 phrases. Français uniquement.""",
        userMessage: userInput,
      ).timeout(_timeout);

      return _extractText(response);
    } catch (_) {
      return "C'est une curiosité sympathique ! On en parlera une autre fois. "
          "Pour l'instant, ma priorité c'est votre santé. Comment puis-je vous aider ?";
    }
  }

  /// Conseils détaillés sur un médicament spécifique
  Future<String> getMedicationAdvice(String medicationName,
      {String? context}) async {
    if (!isAvailable) {
      return "Je ne peux pas donner de conseils pour le moment (configuration manquante).";
    }

    final contextInfo = (context?.isNotEmpty ?? false)
        ? "\n\nHistorique de la conversation :\n$context"
        : "";

    try {
      final response = await _callGemini(
        systemPrompt: """Tu es REBEC-DIN, pharmacien expert à Yaoundé, Cameroun.
Tu as 15 ans d'expérience en pharmacie clinique et conseils aux patients.

IMPORTANT — NE JAMAIS te présenter ou dire "Je suis REBEC-DIN" : l'interface affiche déjà ton identité.
Réponds directement à la question posée, sans introduction.

Pour les questions sur un médicament, structure ta réponse ainsi :
1. 💊 Indication — à quoi ça sert (1 phrase claire)
2. 📋 Posologie standard — doses habituelles adulte/enfant (sans personnaliser)
3. ⏰ Conseil de prise — à jeun ? après repas ? avec beaucoup d'eau ?
4. ⚠️ Précautions principales et contre-indications
5. 🚨 Signes d'alarme nécessitant un médecin immédiatement

RÈGLES ABSOLUES :
- Français uniquement
- Réponse complète, entre 150 et 300 mots — ne pas couper la réponse
- Jamais de dosage personnalisé (toujours "dose standard" ou "selon prescription")
- Toujours rappeler de consulter un professionnel de santé$contextInfo""",
        userMessage: medicationName,
      ).timeout(_timeout);

      return _extractText(response);
    } catch (_) {
      return "Je n'ai pas pu récupérer les conseils. "
          "Veuillez réessayer ou consulter directement un pharmacien.";
    }
  }

  // =========================================================
  // IMPLÉMENTATION INTERNE
  // =========================================================

  Future<List<String>> _readHandwrittenPrescriptionImpl(
      Uint8List imageBytes) async {
    if (!isAvailable) return [];

    try {
      final base64Image = base64Encode(imageBytes);
      final response = await _callGeminiWithImage(
        systemPrompt: """Tu es un expert en lecture de prescriptions médicales.
Analyse cette image de prescription manuscrite.
Réponds UNIQUEMENT avec une liste JSON des médicaments trouvés :
["Médicament 1", "Médicament 2"]
Si aucune prescription claire n'est visible, réponds : []""",
        base64Image: base64Image,
        userMessage: "Lis cette prescription et liste les médicaments.",
      ).timeout(_timeout);

      return _extractMedications(response);
    } catch (_) {
      return [];
    }
  }

  Future<String> _callGemini({
    required String systemPrompt,
    required String userMessage,
  }) async {
    final url = '$_baseUrl?key=$_apiKey';

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userMessage}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1200,
      }
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        return jsonEncode(candidates.first);
      }
    }

    throw Exception(
        'Erreur API Gemini (${response.statusCode}): ${response.body}');
  }

  Future<String> _callGeminiWithImage({
    required String systemPrompt,
    required String base64Image,
    required String userMessage,
  }) async {
    final url = '$_baseUrl?key=$_apiKey';

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userMessage},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 300,
      }
    });

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        return jsonEncode(candidates.first);
      }
    }

    throw Exception(
        'Erreur API Gemini (${response.statusCode}): ${response.body}');
  }

  List<String> _extractMedications(String jsonResponse) {
    try {
      final data = jsonDecode(jsonResponse) as Map<String, dynamic>;
      final content = data['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts != null && parts.isNotEmpty) {
        String text = parts.first['text']?.toString() ?? '[]';
        text = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final parsed = jsonDecode(text);
        if (parsed is List) {
          return List<String>.from(parsed);
        }
      }
    } catch (_) {}
    return [];
  }

  String _extractText(String jsonResponse) {
    try {
      final data = jsonDecode(jsonResponse) as Map<String, dynamic>;
      final content = data['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts != null && parts.isNotEmpty) {
        return parts.first['text']?.toString() ?? '';
      }
    } catch (_) {}
    return '';
  }
}