import 'package:cloud_firestore/cloud_firestore.dart';

enum PharmacyReplyAvailability {
  available,
  unavailable,
  unknown,
}

enum WhatsAppMessageDirection {
  outgoing,
  incoming,
  system;

  static WhatsAppMessageDirection fromJson(String? value) {
    switch (value) {
      case 'outgoing':
        return WhatsAppMessageDirection.outgoing;
      case 'incoming':
        return WhatsAppMessageDirection.incoming;
      default:
        return WhatsAppMessageDirection.system;
    }
  }

  String get jsonValue {
    switch (this) {
      case WhatsAppMessageDirection.outgoing:
        return 'outgoing';
      case WhatsAppMessageDirection.incoming:
        return 'incoming';
      case WhatsAppMessageDirection.system:
        return 'system';
    }
  }
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

class WhatsAppConversationMessage {
  const WhatsAppConversationMessage({
    required this.id,
    required this.direction,
    required this.text,
    required this.createdAt,
  });

  factory WhatsAppConversationMessage.fromJson(Map<String, dynamic> json) {
    return WhatsAppConversationMessage(
      id: json['id']?.toString() ?? '',
      direction: WhatsAppMessageDirection.fromJson(
        json['direction']?.toString(),
      ),
      text: json['text']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
    );
  }

  final String id;
  final WhatsAppMessageDirection direction;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'direction': direction.jsonValue,
      'text': text,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class WhatsAppConversation {
  const WhatsAppConversation({
    required this.id,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.phoneNumber,
    required this.medicationName,
    required this.status,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WhatsAppConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final json = doc.data() ?? <String, dynamic>{};
    final messages = (json['messages'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => WhatsAppConversationMessage.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return WhatsAppConversation(
      id: doc.id,
      pharmacyId: json['pharmacy_id']?.toString() ?? '',
      pharmacyName: json['pharmacy_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      medicationName: json['medication_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending_gateway',
      messages: messages,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  final String id;
  final String pharmacyId;
  final String pharmacyName;
  final String phoneNumber;
  final String medicationName;
  final String status;
  final List<WhatsAppConversationMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isWaitingForReply =>
      status == 'pending_gateway' ||
      status == 'sent' ||
      status == 'waiting_reply';
}

class WhatsAppSendResult {
  const WhatsAppSendResult({
    required this.success,
    this.conversationId,
    this.message,
  });

  final bool success;
  final String? conversationId;
  final String? message;
}

class WhatsAppService {
  WhatsAppService._internal();

  static final WhatsAppService _instance = WhatsAppService._internal();

  factory WhatsAppService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('whatsapp_conversations');

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

  Future<WhatsAppSendResult> sendAvailabilityRequest({
    required String phoneNumber,
    required String pharmacyId,
    required String pharmacyName,
    required String medicationName,
  }) async {
    final normalized = normalizePhoneNumber(phoneNumber);
    if (normalized == null) {
      return const WhatsAppSendResult(
        success: false,
        message: 'Numero WhatsApp invalide.',
      );
    }

    final text = buildAvailabilityRequestMessage(
      pharmacyName: pharmacyName,
      medicationName: medicationName,
    );
    final now = DateTime.now();
    final conversationRef = _conversations.doc();

    try {
      await conversationRef.set({
        'pharmacy_id': pharmacyId,
        'pharmacy_name': pharmacyName,
        'phone_number': normalized,
        'medication_name': medicationName,
        'status': 'pending_gateway',
        'gateway_action': 'send_whatsapp_message',
        'gateway_processed': false,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'messages': [
          WhatsAppConversationMessage(
            id: 'out_${now.microsecondsSinceEpoch}',
            direction: WhatsAppMessageDirection.outgoing,
            text: text,
            createdAt: now,
          ).toJson(),
        ],
      });

      return WhatsAppSendResult(
        success: true,
        conversationId: conversationRef.id,
        message: 'Demande WhatsApp envoyee en arriere-plan.',
      );
    } catch (e) {
      return WhatsAppSendResult(
        success: false,
        message: "Impossible d'envoyer la demande WhatsApp : $e",
      );
    }
  }

  // Kept as a compatibility wrapper for older screens. It no longer opens
  // WhatsApp externally; it queues the message for the in-app gateway flow.
  Future<bool> openAvailabilityRequest({
    required String phoneNumber,
    required String pharmacyName,
    required String medicationName,
  }) async {
    final result = await sendAvailabilityRequest(
      phoneNumber: phoneNumber,
      pharmacyId: '',
      pharmacyName: pharmacyName,
      medicationName: medicationName,
    );
    return result.success;
  }

  Stream<WhatsAppConversation?> watchConversation(String conversationId) {
    return _conversations.doc(conversationId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return WhatsAppConversation.fromFirestore(snapshot);
    });
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

DateTime _parseDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}
