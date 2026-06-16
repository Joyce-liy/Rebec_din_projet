import 'package:url_launcher/url_launcher.dart';

enum PharmacyReplyAvailability {
  available,
  unavailable,
  unknown,
}

class PharmacyReplyInterpretation {
  const PharmacyReplyInterpretation({
    required this.availability,
    required this.summary,
    this.price,
  });

  final PharmacyReplyAvailability availability;
  final String summary;
  final int? price;

  String get priceLabel => price == null ? 'Prix non precise' : '$price FCFA';
}

class WhatsAppService {
  WhatsAppService._internal();

  static final WhatsAppService _instance = WhatsAppService._internal();

  factory WhatsAppService() => _instance;

  String? normalizePhoneNumber(String? rawNumber) {
    if (rawNumber == null) {
      return null;
    }

    var digits = rawNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (!digits.startsWith('237') && digits.length == 9) {
      digits = '237$digits';
    }
    return digits;
  }

  String buildAvailabilityRequestMessage({
    required String pharmacyName,
    required String medicationName,
  }) {
    final medication = medicationName.trim().isEmpty
        ? 'le medicament recherche'
        : medicationName.trim();
    return 'Bonjour $pharmacyName, je souhaite savoir si "$medication" '
        'est disponible dans votre pharmacie et a quel prix. Merci.';
  }

  Future<bool> openAvailabilityRequest({
    required String phoneNumber,
    required String pharmacyName,
    required String medicationName,
  }) async {
    final normalized = normalizePhoneNumber(phoneNumber);
    if (normalized == null) {
      return false;
    }

    final message = buildAvailabilityRequestMessage(
      pharmacyName: pharmacyName,
      medicationName: medicationName,
    );

    final webUri = Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$normalized',
      queryParameters: {'text': message},
    );

    try {
      if (await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Fall back to the native WhatsApp scheme below.
    }

    final appUri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: {
        'phone': normalized,
        'text': message,
      },
    );

    try {
      return launchUrl(appUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  PharmacyReplyInterpretation interpretPharmacyReply(
    String reply, {
    required String pharmacyName,
    required String medicationName,
  }) {
    final normalizedReply = _normalize(reply);
    final price = _extractPrice(reply);
    final unavailable = _containsAny(normalizedReply, const [
      'rupture',
      'indisponible',
      'pas disponible',
      'non disponible',
      'nous navons pas',
      'on na pas',
      'pas en stock',
      'epuise',
      'fini',
    ]);
    final available = _containsAny(normalizedReply, const [
      'disponible',
      'en stock',
      'nous avons',
      'on a',
      'oui',
      'ok',
      'passez',
      'venez',
    ]);

    if (unavailable && !available) {
      return PharmacyReplyInterpretation(
        availability: PharmacyReplyAvailability.unavailable,
        price: price,
        summary: '$pharmacyName indique que "$medicationName" n est pas '
            'disponible pour le moment.',
      );
    }

    if (available || price != null) {
      final priceText = price == null
          ? 'Le prix doit encore etre confirme.'
          : 'Prix indique : $price FCFA.';
      return PharmacyReplyInterpretation(
        availability: PharmacyReplyAvailability.available,
        price: price,
        summary: '$pharmacyName semble confirmer la disponibilite de '
            '"$medicationName". $priceText',
      );
    }

    return PharmacyReplyInterpretation(
      availability: PharmacyReplyAvailability.unknown,
      price: price,
      summary: 'La reponse de $pharmacyName ne permet pas de confirmer '
          'clairement la disponibilite ou le prix de "$medicationName".',
    );
  }

  bool _containsAny(String value, List<String> patterns) {
    return patterns.any((pattern) => value.contains(pattern));
  }

  int? _extractPrice(String text) {
    final match = RegExp(
      r'(\d{2,}(?:[\s.,]\d{3})*|\d+)\s*(?:f\s*cfa|fcfa|cfa|xaf|francs?|f\b)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) {
      return null;
    }

    final digits = match.group(1)?.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits == null || digits.isEmpty) {
      return null;
    }
    return int.tryParse(digits);
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[\u00e0\u00e1\u00e2\u00e3\u00e4\u00e5]'), 'a')
        .replaceAll(RegExp(r'[\u00e8\u00e9\u00ea\u00eb]'), 'e')
        .replaceAll(RegExp(r'[\u00ec\u00ed\u00ee\u00ef]'), 'i')
        .replaceAll(RegExp(r'[\u00f2\u00f3\u00f4\u00f5\u00f6]'), 'o')
        .replaceAll(RegExp(r'[\u00f9\u00fa\u00fb\u00fc]'), 'u')
        .replaceAll(RegExp(r'[\u00e7]'), 'c')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
