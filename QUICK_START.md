# 🚀 Guide d'Intégration Rapide - REBEC-DIN

## ⏱️ Temps d'intégration estimé: 15 minutes

## ✅ Checklist de Mise en Œuvre

### Étape 1: Obtenir la Clé API (2 min)
- [ ] Aller sur https://ai.google.dev/
- [ ] Créer un compte Google gratuit
- [ ] Cliquer "Get API Key"
- [ ] Créer une nouvelle clé pour "Generative API"
- [ ] Copier la clé (commence par `AIzaSy...`)

### Étape 2: Configurer .env (1 min)
```bash
# À la racine de votre projet
touch .env

# Ajouter:
GEMINI_API_KEY=AIzaSy_votre_cle_ici
```

**Important:** Ajouter `.env` à `.gitignore`
```bash
echo ".env" >> .gitignore
```

### Étape 3: Mettre à jour pubspec.yaml (2 min)

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ...existants...
  flutter_dotenv: ^5.0.0
  http: ^1.1.0
  # Assurez-vous d'avoir aussi:
  speech_to_text: ^6.0.0
  flutter_tts: ^0.4.0
  url_launcher: ^6.0.0
```

```bash
flutter pub get
```

### Étape 4: Initialiser dotenv dans main.dart (2 min)

**AVANT:**
```dart
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}
```

**APRÈS:**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Important: Charger avant runApp()
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}
```

### Étape 5: Copier les fichiers de service (3 min)

Assurer-vous que ces fichiers existent:
```
lib/
  ├─ services/
  │  ├─ gemini_service.dart      ✅ (CRÉÉ)
  │  ├─ pharmacy_service.dart    (existant)
  │  └─ location_service.dart    (existant)
  ├─ chat_ai_screen.dart         ✅ (MODIFIÉ)
  ├─ main.dart                   ✅ (À MODIFIER)
  └─ ...
```

### Étape 6: Vérifier les imports (2 min)

Dans `chat_ai_screen.dart`, vérifier:
```dart
import 'package:pharma/services/gemini_service.dart';
```

### Étape 7: Tester (3 min)

```bash
# Terminal
flutter clean
flutter pub get
flutter run

# Dans l'app:
# 1. Dire "Bonjour" → Devrait répondre
# 2. Dire "Aspirin" → Devrait afficher pharmacies
# 3. Dire "Football" → Devrait recadrer intelligemment
```

## 🎯 Points de Vérification

### ✓ La clé API est chargée
```dart
// Dans main.dart, après dotenv.load()
print(dotenv.env['GEMINI_API_KEY']);  // Ne devrait pas être null
```

### ✓ GeminiService est accessible
```dart
final geminiService = GeminiService();
final isAvailable = geminiService.isAvailable;  // true si clé OK
```

### ✓ Classification fonctionne
```dart
final result = await geminiService.isPharmacyRelated("Aspirin");
print(result);  // true
```

## 🐛 Troubleshooting

### Problème: "GEMINI_API_KEY not found"
**Solution:**
1. Vérifier que `.env` existe à la racine
2. Vérifier contenu: `cat .env`
3. Relancer l'app: `flutter clean && flutter run`

### Problème: "Invalid API Key"
**Solution:**
1. Vérifier clé API sur https://ai.google.dev/
2. S'assurer qu'elle commence par `AIzaSy`
3. Vérifier qu'aucun caractère n'a été modifié

### Problème: "Timeout on API call"
**Solutions:**
1. Vérifier connexion internet
2. Augmenter timeout dans `GeminiService`:
   ```dart
   static const Duration _timeout = Duration(seconds: 30);
   ```
3. Vérifier statut API: https://status.openai.com/ (Google Gemini)

### Problème: "No pharmacies found"
**Solution:**
1. Vérifier localisation activée
2. Vérifier que `PharmacyService` fonctionne
3. Vérifier que la position est valide

### Problème: "Messages not appearing"
**Solution:**
1. Vérifier que `flutter_tts` est installé
2. Vérifier permissions Android/iOS pour TTS
3. Vérifier logs: `flutter logs`

## 📱 Permissions Requises

### Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS (Info.plist)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>L'app a besoin de votre localisation pour trouver les pharmacies proches</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>L'app a besoin de la reconnaissance vocale pour le chat</string>

<key>NSMicrophoneUsageDescription</key>
<string>L'app a besoin du microphone pour la reconnaissance vocale</string>
```

## 🔄 Workflow Développeur

### Premier Lancement
```bash
# 1. Clone le repo (si applicable)
git clone <repo>
cd Rebec_din_projet

# 2. Créer .env
cp .env.example .env
# Éditer .env avec votre clé API

# 3. Dépendances
flutter pub get

# 4. Lancer
flutter run
```

### Pendant le développement
```bash
# Hot reload après modification
r          # Hot reload
R          # Hot restart
q          # Quitter

# Voir logs
flutter logs

# Tester sur device
flutter run -d <device_id>

# Build pour production
flutter build apk --split-per-abi
```

## 🎓 Comprendre le Flux

```
1. Utilisateur tape "Paracétamol"
   ↓
2. chat_ai_screen.dart détecte saisie
   ↓
3. Appelle _handleInput("Paracétamol")
   ↓
4. GeminiService.isPharmacyRelated()
   ├─ Appel Gemini: "C'est pharmacie-relatif ?"
   └─ Réponse: "OUI"
   ↓
5. _searchMedication("Paracétamol")
   ├─ Récupère position GPS
   ├─ Liste pharmacies proches
   ├─ Calcule temps de trajet
   └─ Affiche résultats
   ↓
6. Utilisateur choisit pharmacie
   ↓
7. Propose 3 actions:
   ├─ 1: Navigation (Google Maps)
   ├─ 2: Conseils (Gemini API)
   └─ 3: Autre médicament
```

## 📊 Expected Results

### Test 1: Greeting
```
Input:  "Bonjour"
Output: "Bonjour ! Je suis REBEC-DIN..."
```

### Test 2: Medication Search
```
Input:  "Aspirin"
Output: [Liste 5 pharmacies avec distance et temps]
Recommandation: Pharmacie X (la plus rapide)
```

### Test 3: Off-Topic
```
Input:  "Quel est le score du match ?"
Output: [Réponse courtoise recadrant vers pharmacie]
```

### Test 4: Medical Advice
```
Input:  "2" (après avoir sélectionné pharmacie)
Output: [Conseils détaillés sur l'Aspirin par Gemini]
```

## 🔐 Sécurité: Ne pas Oublier

- [ ] `.env` dans `.gitignore`
- [ ] Clé API jamais en dur dans le code
- [ ] Tester avec une clé "test" d'abord
- [ ] Monitorer les appels API
- [ ] Rate limiting activé (si backend)

## 🆘 Support

Si vous rencontrez un problème:

1. **Vérifier les logs:**
   ```bash
   flutter logs | grep "GeminiService"
   ```

2. **Tester l'API manuellement:**
   ```bash
   curl -X POST \
     https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=YOUR_KEY \
     -H "Content-Type: application/json" \
     -d '{"contents":[{"parts":[{"text":"test"}]}]}'
   ```

3. **Vérifier documentation:**
   - Google Gemini API: https://ai.google.dev/
   - Flutter: https://flutter.dev/docs
   - Package dotenv: https://pub.dev/packages/flutter_dotenv

## ✨ Prochaines Étapes Recommandées

1. **Phase 1 (Fait):** IA autonome et intent classification ✅
2. **Phase 2 (Recommandé):** Persistance (SQLite) et historique
3. **Phase 3:** Analytics et monitoring
4. **Phase 4:** Backend API pour scaling

---

**Bravo! Vous avez maintenant une IA pharmacienne complètement fonctionnelle! 🎉**
