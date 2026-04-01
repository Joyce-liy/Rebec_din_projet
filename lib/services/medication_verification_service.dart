import 'dart:convert';
import 'package:http/http.dart' as http;

class MedicationVerificationService {
  MedicationVerificationService._internal();
  static final MedicationVerificationService _instance = 
      MedicationVerificationService._internal();
  factory MedicationVerificationService() => _instance;

  // Cache pour éviter de refaire les mêmes requêtes
  final Map<String, bool> _cache = {};

  /// Vérifie si un médicament existe dans la base de données
  Future<MedicationVerificationResult> verifyMedication(String query) async {
    if (query.trim().isEmpty) {
      return MedicationVerificationResult(
        isValid: false,
        message: 'Veuillez entrer un nom de médicament',
      );
    }

    final normalized = query.toLowerCase().trim();

    // Vérifier le cache d'abord
    if (_cache.containsKey(normalized)) {
      return MedicationVerificationResult(
        isValid: _cache[normalized]!,
        foundName: normalized,
        message: _cache[normalized]!
            ? 'Médicament trouvé'
            : 'Médicament non trouvé',
      );
    }

    try {
      // 1. Essayer OpenFDA (base de données américaine)
      final fdaResult = await _checkOpenFDA(normalized);
      if (fdaResult.isValid) {
        _cache[normalized] = true;
        return fdaResult;
      }

      // 2. Essayer RxNorm (base de données alternative)
      final rxNormResult = await _checkRxNorm(normalized);
      if (rxNormResult.isValid) {
        _cache[normalized] = true;
        return rxNormResult;
      }

      // 3. Si rien trouvé, vérifier les variantes orthographiques
      final variantResult = await _checkVariants(normalized);
      if (variantResult.isValid) {
        _cache[normalized] = true;
        return variantResult;
      }

      // Médicament non trouvé
      _cache[normalized] = false;
      return MedicationVerificationResult(
        isValid: false,
        message: '"$query" ne semble pas être un médicament reconnu',
        suggestions: await _getSuggestions(normalized),
      );
    } catch (e) {
      print('❌ Erreur vérification médicament: $e');
      // En cas d'erreur réseau, on laisse passer (mode dégradé)
      return MedicationVerificationResult(
        isValid: true,
        foundName: query,
        message: 'Vérification impossible, recherche autorisée',
        isDegraded: true,
      );
    }
  }

  /// Vérifie via OpenFDA
  Future<MedicationVerificationResult> _checkOpenFDA(String query) async {
    try {
      final url = Uri.parse(
        'https://api.fda.gov/drug/label.json?search=openfda.brand_name:"$query"+openfda.generic_name:"$query"&limit=1',
      );

      print('🔍 Vérification OpenFDA: $query');

      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final brandName = result['openfda']?['brand_name']?[0];
          final genericName = result['openfda']?['generic_name']?[0];

          print('✅ Médicament trouvé: ${brandName ?? genericName}');

          return MedicationVerificationResult(
            isValid: true,
            foundName: brandName ?? genericName ?? query,
            message: 'Médicament trouvé dans la base OpenFDA',
            source: 'OpenFDA',
          );
        }
      }

      return MedicationVerificationResult(isValid: false);
    } catch (e) {
      print('⚠️ Erreur OpenFDA: $e');
      return MedicationVerificationResult(isValid: false);
    }
  }

  /// Vérifie via RxNorm (NIH - National Library of Medicine)
  Future<MedicationVerificationResult> _checkRxNorm(String query) async {
    try {
      final url = Uri.parse(
        'https://rxnav.nlm.nih.gov/REST/drugs.json?name=$query',
      );

      print('🔍 Vérification RxNorm: $query');

      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['drugGroup']?['conceptGroup'] != null) {
          final concepts = data['drugGroup']['conceptGroup'] as List;
          for (var group in concepts) {
            if (group['conceptProperties'] != null &&
                (group['conceptProperties'] as List).isNotEmpty) {
              final name = group['conceptProperties'][0]['name'];
              print('✅ Médicament trouvé: $name');

              return MedicationVerificationResult(
                isValid: true,
                foundName: name,
                message: 'Médicament trouvé dans la base RxNorm',
                source: 'RxNorm',
              );
            }
          }
        }
      }

      return MedicationVerificationResult(isValid: false);
    } catch (e) {
      print('⚠️ Erreur RxNorm: $e');
      return MedicationVerificationResult(isValid: false);
    }
  }

  /// Vérifie les variantes orthographiques
  Future<MedicationVerificationResult> _checkVariants(String query) async {
    // Variantes communes (avec/sans accents, tirets, etc.)
    final variants = [
      query.replaceAll('-', ' '),
      query.replaceAll(' ', ''),
      _removeAccents(query),
      query.replaceAll('ph', 'f'),
      query.replaceAll('f', 'ph'),
    ];

    for (var variant in variants) {
      if (variant != query) {
        final fdaResult = await _checkOpenFDA(variant);
        if (fdaResult.isValid) return fdaResult;

        final rxResult = await _checkRxNorm(variant);
        if (rxResult.isValid) return rxResult;
      }
    }

    return MedicationVerificationResult(isValid: false);
  }

  /// Obtient des suggestions basées sur la recherche
  Future<List<String>> _getSuggestions(String query) async {
    try {
      // Recherche approximative dans OpenFDA
      final url = Uri.parse(
        'https://api.fda.gov/drug/label.json?search=openfda.brand_name:$query*+openfda.generic_name:$query*&limit=5',
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 3),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<String> suggestions = [];

        if (data['results'] != null) {
          for (var result in data['results']) {
            final brandName = result['openfda']?['brand_name']?[0];
            final genericName = result['openfda']?['generic_name']?[0];

            if (brandName != null && !suggestions.contains(brandName)) {
              suggestions.add(brandName);
            }
            if (genericName != null && !suggestions.contains(genericName)) {
              suggestions.add(genericName);
            }

            if (suggestions.length >= 5) break;
          }
        }

        return suggestions;
      }
    } catch (e) {
      print('⚠️ Erreur suggestions: $e');
    }

    return [];
  }

  /// Retire les accents d'une chaîne
  String _removeAccents(String text) {
    return text
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c');
  }

  /// Vide le cache
  void clearCache() {
    _cache.clear();
  }
}

/// Résultat de la vérification
class MedicationVerificationResult {
  final bool isValid;
  final String? foundName;
  final String message;
  final String? source;
  final List<String> suggestions;
  final bool isDegraded; // Mode dégradé (erreur réseau)

  MedicationVerificationResult({
    required this.isValid,
    this.foundName,
    this.message = '',
    this.source,
    this.suggestions = const [],
    this.isDegraded = false,
  });
}