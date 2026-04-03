# Configuration REBEC-DIN - IA Autonome

## 🎯 Améliorations Implémentées

### 1. **IA Autonome avec Gemini API**
- L'assistant utilise l'API `gemini-2.5-flash` de Google
- Comportement expert : pharmacien professionnel nommé REBEC-DIN
- Basé à Yaoundé, Cameroun
- Tone : professionnel mais empathique

### 2. **Détection d'Intention Intelligente**
- Classification automatique : requête liée à la pharmacie ou hors-sujet
- Recadrage poliment les utilisateurs qui sortent du domaine
- Réponses personnalisées via IA pour chaque contexte hors-sujet

### 3. **Gestion du Contexte**
- Conservation des 5 derniers messages
- L'IA maintient le contexte de la conversation
- L'utilisateur n'a pas besoin de répéter le nom du médicament

### 4. **Logique de Flux Améliorée**
1. Utilisateur entre un médicament
2. L'IA récupère les 5 pharmacies les plus proches
3. Recommandation basée sur distance + temps de trajet estimé (Google Maps)
4. Utilisateur choisit une pharmacie
5. L'IA propose :
   - Lancer l'itinéraire Google Maps
   - Donner des conseils de base sur le médicament
   - Rechercher un autre médicament

### 5. **Robustesse**
- Timeout sur les appels API (15 secondes)
- Gestion d'erreurs avec fallback
- Vérification de la clé API
- Messages d'erreur clairs

## 📋 Configuration

### Prérequis
1. Flutter 3.0+
2. Clé API Google Gemini (gratuite sur https://ai.google.dev/)

### Installation

1. Créez un fichier `.env` à la racine du projet :
```env
GEMINI_API_KEY=votre_clé_api_ici
```

2. Assurez-vous que `flutter_dotenv` est dans votre `pubspec.yaml` :
```yaml
dependencies:
  flutter_dotenv: ^5.0.0
  http: ^1.1.0
```

3. Initialisez dotenv dans `main.dart` :
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}
```

## 🔧 Structure des Services

### `GeminiService`
- `isPharmacyRelated(input)` : Détecte si la requête est liée à la pharmacie
- `getOffTopicResponse(input)` : Génère une réponse de recadrage
- `getMedicationAdvice(medication, context)` : Conseils sur un médicament

### `PharmacyService`
- `fetchNearbyPharmacies()` : Liste les 5 pharmacies les plus proches
- `estimateDrivingTravelTimeSeconds()` : Temps de trajet via Google Maps API

### `LocationService`
- `tryGetCurrentPosition()` : Position GPS de l'utilisateur

## 🎨 Flux Conversationnel

```
Accueil
  ↓
Utilisateur dit un médicament (ou hors-sujet)
  ↓
[Vérification d'intention avec Gemini]
  ├─ Hors-sujet → Réponse de recadrage → Revenir à l'accueil
  └─ Pharmacie-relatif → Recherche
       ↓
   Afficher 5 pharmacies avec:
   - Distance (km)
   - Temps de trajet estimé
   - Recommandation REBEC-DIN
       ↓
   Utilisateur choisit une pharmacie
       ↓
   Options:
   1. Lancer itinéraire → Google Maps
   2. Conseils médic → Gemini API
   3. Autre médicament → Retour au début
```

## 🔐 Sécurité

- La clé API est stockée dans `.env` (ignorée par git)
- Pas de requêtes directives aux utilisateurs sensibles
- Validation des inputs avant appel API

## 📝 Exemples de Prompts Système

### Classification (Intent)
```
Tu es un classifier d'intention pour un assistant pharmacien.
Réponds UNIQUEMENT par "OUI" ou "NON".
```

### Recadrage
```
Tu es REBEC-DIN, un pharmacien expert basé à Yaoundé, Cameroun.
L'utilisateur a posé une question hors de ton domaine d'expertise.
Réponds de manière professionnelle, empathique et courtoise...
```

### Conseils Médicaux
```
Tu es REBEC-DIN, un pharmacien expert basé à Yaoundé, Cameroun.
Tu as 15 ans d'expérience en pharmacie clinique...
- Réponds UNIQUEMENT en français
- Sois concis mais informatif (200 mots max)
```

## 🚀 Prochaines Améliorations

- [ ] Vérification du stock en temps réel
- [ ] Chat persistant (sauvegarde en base de données)
- [ ] Historique des recherches
- [ ] Ratings/avis des pharmacies
- [ ] Intégration SMS pour les rappels de médicaments
