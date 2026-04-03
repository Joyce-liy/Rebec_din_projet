# Configuration Avancée - REBEC-DIN

## 🔧 Variables d'Environnement

### Obligatoires
```env
GEMINI_API_KEY=sk-proj-votre_cle_api_ici
```

### Optionnels (Pour futur développement)
```env
# Google Maps API (pour traffic en temps réel)
GOOGLE_MAPS_API_KEY=AIzaSy...

# Firebase (pour analytics et logging)
FIREBASE_PROJECT_ID=votre-projet
FIREBASE_API_KEY=AIzaSy...

# Sentry (pour error tracking)
SENTRY_DSN=https://...

# Log Level
LOG_LEVEL=INFO  # DEBUG, INFO, WARNING, ERROR
```

## 🎯 Configuration Gemini

### Paramètres API Actuels
```dart
'generationConfig': {
  'temperature': 0.7,      // Créativité (0-1)
  'maxOutputTokens': 500,  // Limite de réponse
  'topP': 0.9,             // Diversité
  'topK': 40,              // Sampling
}
```

### Tuning par Cas d'Usage

#### 1. Classification Intent (Strict)
```dart
'temperature': 0.3,        // Réponses déterministes
'maxOutputTokens': 10,     // OUI/NON court
```

#### 2. Recadrage (Créatif)
```dart
'temperature': 0.8,        // Réponses variées
'maxOutputTokens': 200,    // Plus de flexibilité
```

#### 3. Conseils Médicaux (Équilibré)
```dart
'temperature': 0.5,        // Cohérent mais naturel
'maxOutputTokens': 500,    // Détaillé mais concis
```

## 🔄 Stratégies de Cache

Pour réduire les appels API:

```dart
class GeminiServiceWithCache extends GeminiService {
  final Map<String, String> _cache = {};
  
  Future<String> getMedicationAdviceWithCache(String medication) async {
    final cacheKey = 'advice_$medication';
    
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    
    final advice = await getMedicationAdvice(medication);
    _cache[cacheKey] = advice;
    
    return advice;
  }
}
```

## 📱 Optimisations Mobiles

### 1. Batch Requests
```dart
// Au lieu de 5 appels séquentiels
for (final pharmacy in pharmacies) {
  await estimateTravelTime(pharmacy);  // ❌ Lent
}

// Utiliser Future.wait
final times = await Future.wait([
  estimateTravelTime(pharmacies[0]),
  estimateTravelTime(pharmacies[1]),
  // ...
]);  // ✅ Rapide
```

### 2. Lazy Loading
```dart
// Charger les conseils seulement si demandé
bool _adviceLoaded = false;
String? _cachedAdvice;

Future<String> getAdvice() async {
  if (!_adviceLoaded) {
    _cachedAdvice = await _geminiService.getMedicationAdvice(...);
    _adviceLoaded = true;
  }
  return _cachedAdvice!;
}
```

## 🔐 Sécurité Avancée

### 1. Rate Limiting
```dart
class RateLimitedGeminiService {
  final _requestTimes = <DateTime>[];
  static const _maxRequests = 10;
  static const _timeWindow = Duration(minutes: 1);
  
  Future<bool> canMakeRequest() async {
    final now = DateTime.now();
    _requestTimes.removeWhere(
      (t) => now.difference(t) > _timeWindow
    );
    
    if (_requestTimes.length >= _maxRequests) {
      throw Exception('Rate limit exceeded');
    }
    
    _requestTimes.add(now);
    return true;
  }
}
```

### 2. Input Validation
```dart
String _sanitizeInput(String input) {
  // Limiter la longueur
  if (input.length > 500) {
    throw Exception('Input too long');
  }
  
  // Vérifier les caractères invalides
  if (input.contains(RegExp(r'[<>\"\'%;()&+]'))) {
    throw Exception('Invalid characters');
  }
  
  return input.trim();
}
```

### 3. Token Rotation (Futur)
```dart
class TokenRotationService {
  late String _currentToken;
  late DateTime _tokenExpiry;
  
  Future<String> getValidToken() async {
    if (DateTime.now().isAfter(_tokenExpiry)) {
      await _rotateToken();
    }
    return _currentToken;
  }
  
  Future<void> _rotateToken() async {
    // Implémenter la logique de rotation
    // Stockage sécurisé dans FlutterSecureStorage
  }
}
```

## 🧪 Testing

### Unit Tests pour GeminiService
```dart
void main() {
  group('GeminiService', () {
    test('isPharmacyRelated retourne true pour input valide', () async {
      final service = GeminiService();
      final result = await service.isPharmacyRelated('Aspirin');
      expect(result, true);
    });
    
    test('getOffTopicResponse génère une réponse non-vide', () async {
      final service = GeminiService();
      final response = await service.getOffTopicResponse('Football');
      expect(response.isNotEmpty, true);
    });
  });
}
```

### Integration Tests
```dart
void main() {
  testWidgets('Chat flow complet', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    
    // 1. Entrée utilisateur
    await tester.enterText(find.byType(TextField), 'Paracétamol');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    
    // 2. Vérifier affichage pharmacies
    expect(find.text('Pharmacie'), findsWidgets);
    
    // 3. Sélectionner une pharmacie
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    
    // 4. Vérifier le menu d'action
    expect(find.text('Lancer l\'itinéraire'), findsOneWidget);
  });
}
```

## 📊 Monitoring et Analytics

### Logging Structuré
```dart
import 'package:logger/logger.dart';

final logger = Logger();

// Dans GeminiService
Future<bool> isPharmacyRelated(String userInput) async {
  logger.d('Classifying intent for: $userInput');
  
  try {
    final result = await _callGemini(...);
    logger.i('Intent classification: ${result ? 'pharmacy' : 'off-topic'}');
    return result;
  } catch (e) {
    logger.e('Intent classification failed', error: e);
    return true; // Fallback sûr
  }
}
```

### Métriques à Tracker
```dart
class AnalyticsService {
  void trackMedicationSearch(String medication) {
    // Firebase Analytics, Sentry, etc.
  }
  
  void trackPharmacySelected(String pharmacyName) {
    // Quel pharmacie est choisie
  }
  
  void trackAPIError(String service, Exception error) {
    // Erreurs API pour monitoring
  }
  
  void trackResponseTime(Duration duration) {
    // Performance metrics
  }
}
```

## 🚀 Déploiement

### Pre-Production Checklist
- [ ] Clé API validée
- [ ] Tests unitaires passant
- [ ] Tests intégration passant
- [ ] Rate limiting configuré
- [ ] Logging activé
- [ ] Error tracking configuré
- [ ] Security audit complété

### Build Release
```bash
# Vérifier les secrets
grep -r "GEMINI_API_KEY" lib/  # ❌ Ne pas trouver la clé en dur

# Build
flutter build apk --release
flutter build appbundle --release

# Vérifier obfuscation
cat build/app/outputs/bundle/release/app.aab
```

## 📈 Scaling

Si l'app atteint beaucoup d'utilisateurs:

1. **Backend Gateway**
   ```
   Mobile App → API Gateway → Gemini API
   ```
   Bénéfices: Rate limiting, caching, monitoring

2. **Webhook System**
   ```dart
   // Au lieu d'appels synchrones
   await _apiService.requestAdvice(medicationId);
   // Recevoir notification quand prêt
   ```

3. **Queue System**
   ```dart
   // Batch traitement
   final requests = [req1, req2, req3];
   await _geminiService.batchProcess(requests);
   ```

## 🔍 Debugging

### Logs Détaillés
```dart
// Activer en mode debug
if (kDebugMode) {
  logger.level = Level.debug;
  _enableNetworkLogging();
}

void _enableNetworkLogging() {
  http.Client _innerClient = http.Client();
  
  http.Client _loggingClient = http.Client()
    ..onCreate.listen((request) {
      logger.d('→ ${request.method} ${request.url}');
    });
}
```

### Inspection API
```dart
// Vérifier requête Gemini réelle
print('Request Body:');
print(jsonEncode(requestBody).split('"text":"').skip(1));

print('Response:');
print(jsonEncode(response.body));
```
