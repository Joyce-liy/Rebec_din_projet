import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatAIScreen extends StatefulWidget {
  const ChatAIScreen({super.key});

  @override
  State<ChatAIScreen> createState() => _ChatAIScreenState();
}

class _ChatAIScreenState extends State<ChatAIScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isListening = false;
  String _aiResponse = "Appuyez sur le micro pour parler";

  final _model = GenerativeModel(
  model: 'gemini-1.5-flash',
  apiKey: 'AIzaSyCAdX6UTETLbFBk5y7xTjWZqYq6BzH0j3E',
   
);

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      await _speechToText.initialize();
    } catch (e) {
      print("Erreur d'initialisation : $e");
    }
    if (mounted) setState(() {});
  }

  void _toggleListening() async {
    // On vérifie si le service est disponible
    bool available = await _speechToText.initialize();
    
    if (available) {
      if (_isListening) {
        await _speechToText.stop();
        setState(() => _isListening = false);
      } else {
        setState(() {
          _isListening = true;
          _aiResponse = "Je vous écoute...";
        });
        
        _speechToText.listen(
          onResult: (result) {
            if (result.finalResult) {
              _sendToAI(result.recognizedWords);
              setState(() => _isListening = false);
            }
          },
        );
      }
    } else {
      setState(() {
        _aiResponse = "Micro non autorisé ou non disponible.";
      });
    }
  }

  void _sendToAI(String query) async {
    setState(() => _aiResponse = "Analyse en cours : $query...");
    try {
      final content = [Content.text("En tant que pharmacien, réponds brièvement à : $query")];
      final response = await _model.generateContent(content);
      final textResponse = response.text ?? "Désolé, je n'ai pas pu générer de réponse.";
      
      setState(() => _aiResponse = textResponse);
      await _flutterTts.speak(textResponse);
    } catch (e) {
      setState(() => _aiResponse = "Erreur Gemini : $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255), // Ton fond foncé
      appBar: AppBar(
        title: const Text("Assistant Pharma IA"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône animée
            Icon(
              _isListening ? Icons.graphic_eq : Icons.auto_awesome_rounded,
              size: 100,
              color: _isListening ? Colors.red : Color.fromARGB(221, 130, 213, 119),
            ),
            const SizedBox(height: 30),
            // Zone de texte
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _aiResponse,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Color.fromARGB(221, 130, 213, 119)),
                ),
              ),
            ),
            const SizedBox(height: 50),
            // Bouton Micro
            ElevatedButton(
              onPressed: _toggleListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : const Color.fromARGB(255, 78, 180, 90),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(30),
              ),
              child: Icon(
                _isListening ? Icons.stop : Icons.mic,
                size: 40,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}