# 🏗️ Architecture et FAQ - REBEC-DIN

## 📐 Diagramme d'Architecture Complète

```
┌─────────────────────────────────────────────────────────────┐
│                     REBEC-DIN Mobile App                    │
│                      (Flutter + Dart)                        │
└─────────────────────────────────────────────────────────────┘
                              ▼
                    ┌─────────────────┐
                    │  Chat UI Screen │ (chat_ai_screen.dart)
                    │                 │
                    │ • Messages List │
                    │ • Input Field   │
                    │ • Mic/TTS       │
                    └────────┬────────┘
                             │
                    ┌────────┴────────┐
                    ▼                 ▼
            ┌──────────────┐  ┌──────────────────┐
            │ User Message │  │ AI Orchestrator  │
            │  Processing  │  │  (State Machine) │
            └──────┬───────┘  └────────┬─────────┘
                   │                   │
         ┌─────────▼────────────────────▼──────────┐
         │      Service Layer (Business Logic)     │
         ├─────────────────────────────────────────┤
         │                                         │
         │  ┌────────────────────────────────────┐ │
         │  │    GeminiService (NOUVEAU)         │ │
         │  ├────────────────────────────────────┤ │
         │  │ • isPharmacyRelated()              │ │
         │  │ • getOffTopicResponse()            │ │
         │  │ • getMedicationAdvice()            │ │
         │  │ • Context Management              │ │
         │  └────────────────────────────────────┘ │
         │                                         │
         │  ┌────────────────────────────────────┐ │
         │  │    PharmacyService                 │ │
         │  ├────────────────────────────────────┤ │
         │  │ • fetchNearbyPharmacies()          │ │
         │  │ • estimateDrivingTime()            │ │
         │  │ • searchPharmacy()                 │ │
         │  └────────────────────────────────────┘ │
         │                                         │
         │  ┌────────────────────────────────────┐ │
         │  │    LocationService                 │ │
         │  ├────────────────────────────────────┤ │
         │  │ • getCurrentPosition()             │ │
         │  │ • Permission Handling              │ │
         │  └────────────────────────────────────┘ │
         │                                         │
         └────────────┬────────────────────────────┘
                      │
         ┌────────────┴────────────────┐
         ▼                             ▼
    ┌──────────────┐          ┌──────────────────┐
    │  GPS/Maps    │          │  External APIs   │
    │              │          │                  │
    │ • Location   │          │ • Google Gemini  │
    │ • Travel Time│          │ • Google Maps    │
    └──────────────┘          │ • Pharmacy DB    │
                              └──────────────────┘
```

## 🔄 Flux de Données (Data Flow)

```
USER INPUT
    │
    ▼
┌─────────────────────────────┐
│ 1. Speech Recognition       │ (speech_to_text)
│    ou Typing                │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ 2. Text Processing          │
│    • Trim/Lowercase         │
│    • Parse Numbers          │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ 3. Intent Classification    │ ← Gemini API
│    isPharmacyRelated()      │
└───────┬──────────────────┬──┘
        │ OUI              │ NON
        │                  │
        ▼                  ▼
┌──────────────┐   ┌──────────────┐
│ Process as   │   │ Get Off-Topic│
│ Medication   │   │ Response     │
│ Search       │   │ (Gemini API) │
└──────┬───────┘   └──────┬───────┘
       │                   │
       ▼                   ▼
   [Search Flow]      [Return Response]
       │                   │
       └──────────┬────────┘
                  │
                  ▼
          ┌──────────────┐
          │ Display in   │
          │ Chat UI      │
          └──────┬───────┘
                 │
                 ▼
          ┌──────────────┐
          │ TTS Speak    │ (flutter_tts)
          │ Response     │
          └──────────────┘
```

## 📊 État Machine (State Machine)

```
┌─────────────────────────────────────────┐
│         idle (Recherche)                │  ← État initial
│                                         │
│ • Écoute requête utilisateur            │
│ • Classifie intention                   │
│ • Lance recherche si pharmacie-relatif  │
└──────────┬──────────────────────────────┘
           │
           │ [Médicament trouvé + Pharmacies listées]
           │
           ▼
┌─────────────────────────────────────────┐
│  awaitingPharmacyChoice                 │
│  (Choix de Pharmacie)                   │
│                                         │
│ • Affiche 5 pharmacies                  │
│ • Attend choix (1-5)                    │
│ • Vérifie validité du choix             │
└──────────┬──────────────────────────────┘
           │
           │ [Numéro valide saisi]
           │
           ▼
┌─────────────────────────────────────────┐
│  awaitingActionChoice                   │
│  (Menu Pharmacie)                       │
│                                         │
│ Options:                                │
│ 1. Navigation (Google Maps)             │
│ 2. Conseils Médicaux (Gemini)           │
│ 3. Autre Médicament                     │
└──────────┬──────────────────────────────┘
           │
        ┌──┼──┬─────────┐
        │  │  │         │
        ▼  ▼  ▼         ▼
      [1] [2] [3]   [Invalide]
        │  │  │         │
        │  │  │    [Message erreur]
        │  │  │         │
        │  │  └────┐    │
        │  └───────┼────┤
        │          │    │
        └──────────┼────┘
                   │
                   ▼
           ┌──────────────┐
           │   idle       │ ← Retour à l'état initial
           └──────────────┘
```

## 🗂️ Arborescence Finale du Projet

```
Rebec_din_projet/
├── lib/
│   ├── main.dart                    ← Initialisation (dotenv)
│   ├── chat_ai_screen.dart          ← UI Principal
│   ├── models/
│   │   └── pharmacy.dart            (existant)
│   ├── services/
│   │   ├── gemini_service.dart      ← ✨ NOUVEAU (IA)
│   │   ├── pharmacy_service.dart    (existant)
│   │   └── location_service.dart    (existant)
│   ├── utils/
│   │   └── geo_utils.dart           (existant)
│   ├── theme/
│   │   └── app_theme.dart           (existant)
│   └── widgets/
│       └── (futurs composants)
├── assets/
│   └── (images, fonts, etc.)
├── test/
│   ├── unit/
│   │   └── services/
│   │       └── gemini_service_test.dart
│   └── integration/
│       └── chat_ai_screen_test.dart
├── android/
│   └── app/
│       └── src/main/AndroidManifest.xml (permissions)
├── ios/
│   └── Runner/
│       └── Info.plist (permissions)
├── .env                            ← Secrets (ne pas commiter)
├── .env.example                    ← Template
├── .gitignore                      (contient .env)
├── pubspec.yaml                    (dependencies)
├── pubspec.lock
├── README.md                       (existant)
├── REBEC_DIN_AI.md                 ← Documentation IA
├── CHANGELOG.md                    ← Changements
├── QUICK_START.md                  ← Guide rapide
├── ADVANCED_CONFIG.md              ← Config avancée
├── PROMPTS_LIBRARY.md              ← Prompts customisés
├── TESTING.md                      ← Cas de test
├── ARCHITECTURE.md                 ← Ce fichier
└── main_example.dart               ← Exemple initialisation
```

---

## ❓ FAQ (Foire Aux Questions)

### 🔑 Clé API et Configuration

**Q: Où obtenir la clé API Gemini ?**
A: https://ai.google.dev/ → "Get API Key" → Générée automatiquement

**Q: La clé API est gratuite ?**
A: Oui! Google offre 60 requêtes/minute gratuites (plus que suffisant pour une app)

**Q: Comment sécuriser ma clé API ?**
A: Utilisez `.env` et ajoutez-le à `.gitignore`. JAMAIS en dur dans le code.

**Q: Si quelqu'un vole ma clé ?**
A: Régénérez-la sur https://ai.google.dev/ et mettez à jour `.env`

**Q: Peut-on avoir plusieurs clés API ?**
A: Oui, créez plusieurs clés pour dev/prod/test

---

### 💻 Développement

**Q: Comment déboguer les appels Gemini ?**
A: 
```dart
print('Request: $systemPrompt');
print('Response: $response');
// Ou utilisez logger package
```

**Q: Les requêtes API sont lentes, pourquoi ?**
A: 
- Vérifier connexion internet
- Vérifier statut Google Gemini
- Augmenter timeout (actuellement 15s)

**Q: Comment tester sans API réelle ?**
A: Mock la GeminiService:
```dart
class MockGeminiService extends GeminiService {
  @override
  Future<bool> isPharmacyRelated(_) async => true;
}
```

**Q: Can I use local/offline models?**
A: Oui, mais nécessite beaucoup de resources mobiles. Gemini API est plus pratique.

---

### 📱 Déploiement et Performance

**Q: Quel est le coût de déploiement ?**
A: 
- Développement: GRATUIT (API gratuite Google)
- Production: Dépend du trafic (au-delà 60 req/min, paiement)

**Q: L'app fonctionne hors-ligne ?**
A: Partiellement. GPS OK, mais IA/Pharmacies nécessitent internet.

**Q: Quel est le temps réponse moyen ?**
A:
- Classification intention: 1-2s
- Liste pharmacies: 2-3s
- Conseils médicaux: 2-4s

**Q: Comment scaler pour 100K utilisateurs ?**
A: Mettre un backend en place:
```
App → Backend API → Gemini API
```
(Le backend cache les réponses)

---

### 🤖 IA et Comportement

**Q: Pourquoi l'IA recadre parfois mal ?**
A: Gemini n'est pas parfait (accuracy ~95%). Améliorer le prompt!

**Q: Peut-on avoir un IA multilingue ?**
A: Oui! Modifier les prompts pour inclure plusieurs langues

**Q: L'IA peut prescrire des médicaments ?**
A: NON. Les prompts interdisent explicitement cela.

**Q: Comment l'IA maintient le contexte ?**
A: On envoie les 5 derniers messages avec chaque requête.

---

### 🛠️ Troubleshooting

**Q: "GEMINI_API_KEY not found"**
A:
1. Vérifier `.env` existe
2. Vérifier format: `GEMINI_API_KEY=AIzaSy...`
3. Relancer: `flutter clean && flutter run`

**Q: "Invalid API Key"**
A:
1. Vérifier clé sur https://ai.google.dev/
2. Vérifier pas d'espace ou caractères supplémentaires
3. Regénérer une nouvelle clé si doute

**Q: "Timeout"**
A:
1. Vérifier internet
2. Augmenter timeout dans GeminiService
3. Vérifier status API Google

**Q: Les permissions ne marchent pas**
A:
- Android: Vérifier AndroidManifest.xml
- iOS: Vérifier Info.plist
- Relancer l'app après changements

---

### 📊 Analytics et Monitoring

**Q: Comment tracker les erreurs ?**
A: Intégrer Sentry, Firebase Crashlytics, ou custom logging

**Q: Quelles métriques tracker ?**
A:
- Nombre recherches/jour
- Pharmacies les plus cherchées
- Taux d'erreur API
- Temps réponse moyen

**Q: RGPD - Comment gérer les données ?**
A: Ne jamais sauvegarder les requêtes sensibles. Utiliser only memory storage.

---

### 🎓 Apprentissage et Amélioration

**Q: Comment améliorer la précision de l'IA ?**
A:
1. Tester différents prompts (A/B testing)
2. Ajouter exemples dans le prompt
3. Utiliser un modèle plus puissant (gemini-pro)
4. Collecte de feedback utilisateur

**Q: Peut-on fine-tuner le modèle ?**
A: Pas pour Gemini 2.5 flash directement, mais on peut:
- Créer des prompts très sophistiqués
- Utiliser RAG (Retrieval Augmented Generation)
- Ajouter context externe

**Q: Comment contribuer à l'amélioration ?**
A: Voir CONTRIBUTING.md (à créer)

---

## 📚 Ressources Additionnelles

### Documentation Officielle
- [Google Gemini API](https://ai.google.dev/)
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language](https://dart.dev/guides)

### Packages Utilisés
- [flutter_dotenv](https://pub.dev/packages/flutter_dotenv)
- [http](https://pub.dev/packages/http)
- [speech_to_text](https://pub.dev/packages/speech_to_text)
- [flutter_tts](https://pub.dev/packages/flutter_tts)

### Tutoriels Recommandés
- Building AI Apps with Flutter
- Google Gemini API Integration
- State Management in Flutter (Provider, Riverpod)

---

## 🎯 Roadmap Futur

### Version 2.0 (2-3 mois)
- [ ] Persistance des données (SQLite)
- [ ] Analytics détaillées
- [ ] Push notifications
- [ ] Mode offline partiel

### Version 3.0 (3-6 mois)
- [ ] Backend API
- [ ] Authentification utilisateur
- [ ] Prédictions ML
- [ ] Intégration SMS

### Version 4.0 (6+ mois)
- [ ] Multi-language support
- [ ] Voice input amélioré
- [ ] Partnering avec vraies pharmacies
- [ ] Vérification stock en temps réel

---

**Questions supplémentaires ? Ouvrir une issue sur GitHub! 🐙**
