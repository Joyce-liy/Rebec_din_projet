import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class GeminiService {
  // ⚠️ REMPLACEZ PAR VOTRE CLÉ
  static const String _apiKey = "AIzaSyDKTFu8aOuVZ8WrN8zu25reZ9dhuedrVfA";
  
  // ✅ Utilisation de gemini-2.5-flash (le meilleur modèle disponible)
  static const String _apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey";

  static Future<List<String>> readHandwrittenPrescription(Uint8List imageBytes) async {
    try {
      print("🚀 DÉBUT : Envoi de l'image à Gemini 2.5 Flash...");

      final Map<String, dynamic> requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": "Identifie les noms de médicaments sur cette ordonnance. Répond uniquement avec les noms séparés par des virgules."
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Encode(imageBytes) 
                }
              }
            ]
          }
        ]
      };

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      print("📥 Code réponse : ${response.statusCode}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final String? resultText = data['candidates'][0]['content']['parts'][0]['text'];
          
          if (resultText != null) {
            print("✅ SUCCÈS : Médicaments détectés : $resultText");
            return resultText
                .split(',')
                .map((e) => e.trim().replaceAll('*', ''))
                .where((e) => e.length > 2)
                .toList();
          }
        }
        print("⚠️ Aucun résultat dans la réponse");
        return [];
      } else {
        print("❌ ERREUR API (${response.statusCode}): ${response.body}");
        return [];
      }
    } catch (e) {
      print("❌ ERREUR : $e");
      return [];
    }
  }
}