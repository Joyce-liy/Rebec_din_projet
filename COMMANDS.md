# 🛠️ Commandes et CLI Utiles - REBEC-DIN

## 📋 Commandes Flutter de Base

### Setup Initial
```bash
# Créer un nouveau projet Flutter
flutter create rebec_din

# Naviguer dans le projet
cd rebec_din

# Vérifier environment
flutter doctor

# Afficher device
flutter devices
```

### Développement
```bash
# Lancer l'app en debug mode
flutter run

# Sur device spécifique
flutter run -d <device_id>

# Hot reload (conservation état)
r

# Hot restart (rebuild complet)
R

# Quitter
q

# Logs en continu
flutter logs

# Logs d'un device spécifique
flutter logs -d <device_id>

# Nettoyer (recommandé après problèmes)
flutter clean

# Récupérer dépendances
flutter pub get

# Mettre à jour dépendances
flutter pub upgrade
```

### Build et Release
```bash
# Build Debug APK (Android)
flutter build apk --debug

# Build Release APK (optimisé)
flutter build apk --release

# Build split per ABI (taille réduite)
flutter build apk --split-per-abi

# Build AppBundle (Google Play)
flutter build appbundle --release

# Build iOS
flutter build ios --release

# Build Web (si enabled)
flutter build web --release

# Taille APK
apk dump info app/build/outputs/apk/release/app-release.apk

# Liste les ressources
flutter pub pub global list
```

### Analyse du Code
```bash
# Vérifier erreurs et warnings
flutter analyze

# Format le code (Dart style)
dart format lib/ -i

# Vérifier style
dart format lib/ --set-exit-if-changed

# Linter strict
dart analyze --fatal-infos

# Test couverture
flutter test --coverage

# Genérer rapport couverture
lcov -l coverage/lcov.info
```

---

## 🔧 Commandes Dart/Package

### Gestion des Dépendances
```bash
# Ajouter une dépendance
flutter pub add package_name

# Ajouter en dev dependency
flutter pub add --dev package_name

# Supprimer une dépendance
flutter pub remove package_name

# Afficher dépendances
flutter pub deps

# Afficher dépendances transitive
flutter pub deps --style=list

# Vérifier outdated packages
flutter pub outdated

# Mettre à jour un package
flutter pub upgrade package_name

# Mettre à jour tout
flutter pub upgrade

# Downgrade un package
flutter pub downgrade package_name:version

# Cache clean
flutter pub cache clean
```

### Pub.dev Interaction
```bash
# Login à pub.dev (avant publish)
pub login

# Publier un package
pub publish

# Valider avant publish
pub publish --dry-run

# Logout
pub logout
```

---

## 🧪 Commandes de Test

### Tests Unitaires
```bash
# Lancer tous les tests
flutter test

# Un fichier de test spécifique
flutter test test/services/gemini_service_test.dart

# Tests avec verbose output
flutter test -v

# Tests en watch mode (re-run on change)
flutter test --watch

# Générer coverage report
flutter test --coverage
```

### Tests Intégration
```bash
# Lancer tous les tests intégration
flutter test integration_test/

# Spécifique test d'intégration
flutter test integration_test/chat_ai_screen_test.dart

# Rebuild app à chaque test
flutter test --rebuild
```

### Vérification Dynamique
```bash
# Profiler l'app
flutter run --profile

# Trace les performances
flutter run --trace-startup > startup_trace.txt

# Memory snapshot
flutter run --verbose 2>&1 | grep memory
```

---

## 📦 Commandes Android (Gradle)

```bash
# Build APK directement
./gradlew assembleRelease

# Build AppBundle
./gradlew bundleRelease

# Afficher dépendances
./gradlew dependencies

# Clean Gradle cache
./gradlew clean

# Vérifier lint Android
./gradlew lint

# Signer APK
jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 \
  -keystore key.jks app-release-unsigned.apk alias_name

# Align ZIP pour Google Play
zipalign -v 4 app-release-unsigned.apk app-release.apk
```

---

## 🍎 Commandes iOS (Xcode)

```bash
# Build iOS
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -derivedDataPath build/

# Pods update
cd ios && pod install --repo-update && cd ..

# Clean Xcode cache
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Code signing check
security find-identity -v -p codesigning
```

---

## 🔌 Commandes Git

### Configuration
```bash
# Config utilisateur (premier setup)
git config --global user.name "Votre Nom"
git config --global user.email "votre@email.com"

# Config repo spécifique
git config user.name "Votre Nom"
```

### Opérations de Base
```bash
# Initialiser repo
git init

# Cloner un repo
git clone <url>

# Voir statut
git status

# Voir diff
git diff

# Voir branches
git branch -a

# Créer branche
git branch feature/ma-feature

# Switch branche
git checkout feature/ma-feature

# Créer + switch
git checkout -b feature/ma-feature
```

### Commit
```bash
# Ajouter tous les fichiers
git add .

# Ajouter fichier spécifique
git add lib/chat_ai_screen.dart

# Commit avec message
git commit -m "Feat: ajouter GeminiService"

# Commit avec description longue
git commit -m "Feat: ajouter GeminiService

- Implémente classification d'intention
- Ajoute gestion contexte
- Améliore robustesse"

# Amender dernier commit
git commit --amend

# Push commits
git push origin feature/ma-feature

# Pull commits
git pull origin feature/ma-feature
```

### Branching Workflow (Git Flow)
```bash
# Créer feature branche
git checkout -b feature/gemini-integration

# Après test, créer PR/MR
# (Sur GitHub/GitLab interface)

# Après merge, delete branche locale
git branch -d feature/gemini-integration

# Delete branche remote
git push origin --delete feature/gemini-integration
```

---

## 📊 Commandes de Monitoring

### Firebase (si configuré)
```bash
# Login Firebase
firebase login

# Initialiser Firebase
firebase init

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Voir logs Firebase
firebase functions:log
```

### Analytics personnalisé
```bash
# Envoyer event
FirebaseAnalytics.instance.logEvent(
  name: 'medication_search',
  parameters: {'medication': 'Paracétamol'},
);
```

---

## 🐛 Debugging Avancé

### DevTools
```bash
# Lancer DevTools
flutter pub global activate devtools
devtools

# Ou depuis l'app en cours
flutter run
# Puis copier URL devtools dans browser

# Debugger Flutter
flutter run -d <device> --start-paused
```

### Logs Structurés
```dart
import 'package:logger/logger.dart';

final logger = Logger();

logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message');
```

### Profiling Mémoire
```bash
# Profiler memory usage
flutter run --profile

# Memory trace
dart --observe run lib/main.dart
# Puis accéder à observatory:8181
```

---

## 🚀 Déploiement (Production)

### Google Play Store
```bash
# Augmenter build number
# Dans pubspec.yaml: version: 1.0.0+2

# Build release
flutter build appbundle --release

# Créer clé signing (une seule fois)
keytool -genkey -v -keystore \
  ~/.android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 \
  -validity 10950 -alias upload

# Upload sur Google Play Console
# (Via interface web)
```

### TestFlight (iOS)
```bash
# Build iOS release
flutter build ios --release

# Puis via Xcode organizer
# Upload to TestFlight
```

---

## 📋 Script d'Automatisation (Optional)

### Script Build Complet
```bash
#!/bin/bash
# build.sh

echo "🧹 Cleaning..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "✅ Running tests..."
flutter test

echo "🔍 Analyzing code..."
flutter analyze

echo "🎨 Formatting..."
dart format lib/ -i

echo "📱 Building APK Release..."
flutter build apk --release

echo "✨ Build complete!"
echo "APK location: build/app/outputs/apk/release/app-release.apk"
```

Utilisation:
```bash
chmod +x build.sh
./build.sh
```

---

## ⚡ Alias Utiles (.bashrc ou .zshrc)

```bash
# Flutter aliases
alias fclean="flutter clean && flutter pub get"
alias ftest="flutter test"
alias fanalyze="flutter analyze"
alias fformat="dart format lib/ -i"
alias fdebug="flutter run -d chrome"
alias frelease="flutter build apk --release"

# Quick git
alias gs="git status"
alias ga="git add ."
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline"

# Project specific
alias rebec="cd ~/Documents/Rebec_din_projet && flutter run"
```

---

## 📚 Ressources Commandes

- [Flutter CLI Reference](https://flutter.dev/docs/reference/flutter-cli)
- [Dart CLI](https://dart.dev/tools/dart-tool)
- [Git Cheat Sheet](https://git-scm.com/docs)
- [Gradle Guide](https://gradle.org/guide/)

---

**Astuce:** Sauvegardez vos commandes utiles dans un alias! ⚡
