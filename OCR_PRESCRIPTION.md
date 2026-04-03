# 📸 Fonctionnalité OCR Prescription - REBEC-DIN

## 🎯 Description

REBEC-DIN peut maintenant lire les prescriptions manuscrites à partir d'images.

### Méthode Disponible

```dart
Future<List<String>> readHandwrittenPrescription(List<int> imageBytes)
```

## 💻 Utilisation

### Exemple dans scanner_page.dart

```dart
// 1. Capturer l'image de la prescription
final imageBytes = // ... bytes de l'image

// 2. Appeler GeminiService
final geminiService = GeminiService();
final medications = await geminiService.readHandwrittenPrescription(imageBytes);

// 3. Résultat: List<String> des médicaments trouvés
// ["Paracétamol 500mg", "Amoxicilline 1000mg", "Ibuprofen 400mg"]

// 4. Itérer sur les résultats
for (final medication in medications) {
  print("Trouvé: $medication");
  // Lancer recherche pharmacie pour chaque
}
```

## 🔍 Comment Ça Marche

1. **Capture Image** → bytes de l'image
2. **Encodage Base64** → envoyer à Gemini
3. **Vision API** → Gemini analyse l'image
4. **Extraction** → liste des médicaments
5. **Retour** → List<String>

### Architecture du Flux

```
Scanner/Camera
    ↓
Capture Image (bytes)
    ↓
GeminiService.readHandwrittenPrescription()
    ↓
Base64Encode
    ↓
HTTP POST to Gemini Vision API
    ↓
Response: JSON avec médicaments
    ↓
Parse & Extract
    ↓
Return List<String>
    ↓
Use avec _searchMedication()
```

## 📋 Détails Technique

### Paramètres

```dart
Future<List<String>> readHandwrittenPrescription(List<int> imageBytes)
```

- **imageBytes** : Les bytes de l'image (JPEG, PNG, WebP)
- **Retour** : Liste des médicaments trouvés

### Format de Réponse

```dart
// Réussi:
["Paracétamol 500mg", "Aspirin 250mg"]

// Pas de prescription détectée:
[]

// Erreur réseau/API:
[]
```

## ⚙️ Configuration Gemini

### System Prompt Utilisé

```
Tu es un expert en lecture de prescriptions médicales.
Analyse cette image de prescription manuscrite.

Réponds avec une liste JSON des médicaments trouvés:
["Médicament 1", "Médicament 2", "Médicament 3"]

Si pas de prescription claire, réponds: []
```

### Paramètres API

```dart
'temperature': 0.3,        // Réponses déterministes
'maxOutputTokens': 200,    // Prescription courte généralement
```

## 🖼️ Formats d'Image Supportés

```
✓ JPEG
✓ PNG
✓ WebP
✓ GIF
✗ Trop petites (< 32 pixels)
✗ Trop floues
✗ Rotations bizarres
```

## 🎯 Cas d'Usage

### Cas 1: Scanner Physique
```dart
// Utilisateur prend photo d'une prescription papier
final imageFile = File('path/to/prescription.jpg');
final bytes = await imageFile.readAsBytes();
final medications = await geminiService.readHandwrittenPrescription(bytes);
```

### Cas 2: Upload depuis Galerie
```dart
// Image picker
final ImagePicker _picker = ImagePicker();
final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
final bytes = await image?.readAsBytes();
final medications = await geminiService.readHandwrittenPrescription(bytes!);
```

### Cas 3: Photo Live
```dart
// Caméra temps réel
final result = await _cameraController.takePicture();
final bytes = await result.readAsBytes();
final medications = await geminiService.readHandwrittenPrescription(bytes);
```

## ⚠️ Limitations

### Reconnaissance

```
✓ Écritures claires et lisibles
✓ Prescriptions en français
✓ Format médical standard
✗ Écritures très cursives
✗ Prescriptions mal scannées/floues
✗ Langues non reconnaissables
```

### À Considérer

```
- Qualité image = qualité résultat
- Éclairage important
- Angle optimal ~90 degrés
- Pas trop éloigné du texte
- Prescriptions partiellement visibles = résultat incomplet
```

## 🔒 Sécurité et Privacy

### Données Traitées

```
✅ Envoyé à Google Gemini API (HTTPS)
✅ Traité temporairement
✅ Pas de stockage côté serveur
⚠️  Utilisateur doit accepter conditions Google
```

### Recommandations

```
1. Informer l'utilisateur que l'image est traitée par IA
2. Ne pas sauvegarder images localement sans consentement
3. Montrer disclaimer médical
4. Rappeler que c'est assistive, pas définitif
```

## 📝 Disclaimer à Afficher

```
⚠️  ATTENTION:
Cette technologie est assistive seulement.
La lecture automatique de prescriptions peut contenir des erreurs.
TOUJOURS vérifier auprès d'un pharmacien avant de prendre des médicaments.
Les prescriptions manuscrites ambiguës peuvent ne pas être lues correctement.
En cas de doute, demander clarification au médecin prescripteur.
```

## 🧪 Tests

### Test Unitaire Recommandé

```dart
test('readHandwrittenPrescription returns list of medications', () async {
  final service = GeminiService();
  final testImageBytes = // ... bytes valides
  
  final result = await service.readHandwrittenPrescription(testImageBytes);
  
  expect(result, isA<List<String>>());
  expect(result.length, greaterThan(0));
  expect(result.first, contains('mg')); // Supposé contenir dosage
});

test('readHandwrittenPrescription returns empty on invalid image', () async {
  final service = GeminiService();
  final invalidBytes = [0, 1, 2, 3]; // Pas une image valide
  
  final result = await service.readHandwrittenPrescription(invalidBytes);
  
  expect(result, isEmpty);
});
```

## 🚀 Intégration dans scanner_page.dart

### Exemple Complet

```dart
class ScannerPage extends StatefulWidget {
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final GeminiService _geminiService = GeminiService();
  
  Future<void> _processPrescriptionImage(List<int> imageBytes) async {
    try {
      // 1. Lire la prescription
      final medications = await _geminiService.readHandwrittenPrescription(imageBytes);
      
      if (medications.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(text: 'Aucune prescription détectée'),
        );
        return;
      }
      
      // 2. Pour chaque médicament trouvé
      for (final medication in medications) {
        // 3. Chercher pharmacies
        await _searchMedicationPharmacy(medication);
      }
      
    } catch (e) {
      print('Erreur: $e');
    }
  }
  
  Future<void> _searchMedicationPharmacy(String medication) async {
    // Utiliser logique existante chat_ai_screen.dart
    // _searchMedication(medication);
  }
}
```

## 🎨 UI Considerations

### Loading State
```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    title: Text('Lecture en cours...'),
    content: SizedBox(
      height: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyse de la prescription'),
        ],
      ),
    ),
  ),
);
```

### Result Display
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Médicaments Trouvés'),
    content: ListView.builder(
      itemCount: medications.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(medications[index]),
          trailing: IconButton(
            icon: Icon(Icons.search),
            onPressed: () => _searchMedicationPharmacy(medications[index]),
          ),
        );
      },
    ),
  ),
);
```

## 📊 Métriques à Tracker

```dart
analytics.logEvent(
  name: 'prescription_scanned',
  parameters: {
    'medications_found': medications.length,
    'image_quality': imageQuality,
    'processing_time_ms': duration.inMilliseconds,
    'success': medications.isNotEmpty,
  },
);
```

## 🔄 Flux Complet Utilisateur

```
1. Ouvrir Scanner (camera_page)
   ↓
2. Prendre photo prescription
   ↓
3. REBEC-DIN lit prescription
   ↓
4. Afficher médicaments trouvés
   ↓
5. Utilisateur confirme/corrige
   ↓
6. Chercher pharmacies pour chaque
   ↓
7. Afficher résultats combinés
   ↓
8. Sélectionner une pharmacie
   ↓
9. Menu action (navigation, conseils, autre)
```

## 🎯 Prochaines Améliorations

- [ ] Validation des médicaments (vérifier s'ils existent)
- [ ] Extraction du dosage exact
- [ ] Détection de la date de prescription
- [ ] OCR amélioré avec preprocessing image
- [ ] Sauvegarde historique prescriptions
- [ ] Partage prescriptions (email, WhatsApp)
- [ ] Intégration avec ordonnance numérique

---

**La fonctionnalité OCR est maintenant prête à l'emploi! 📸✨**
