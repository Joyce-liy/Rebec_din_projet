class Pharmacy {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String telephone;
  final String whatsapp; // Format: 2376XXXXXXXX
  final bool isActive;   // Disponibilité de l'officine

  Pharmacy({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.telephone,
    required this.whatsapp,
    this.isActive = true,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'nom': name,
      'adresse': address,
      'localisation': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'telephone': telephone,
      'whatsapp': whatsapp,
      'is_active': isActive,
    };
  }
}