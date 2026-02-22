import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:pharma/theme/app_theme.dart';
import '../services/location_service.dart';
import 'custom_map_theme.dart';


class MedicationMapPage extends StatefulWidget {
  final MedicationCatalogEntry entry;
  final GeoPoint? initialUserLocation;

  const MedicationMapPage({
    super.key,
    required this.entry,
    required this.initialUserLocation,
  });

  @override
  State<MedicationMapPage> createState() => _MedicationMapPageState();
}

class _MedicationMapPageState extends State<MedicationMapPage> {
  MapLibreMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final userLoc = widget.initialUserLocation;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Pharmacies - ${widget.entry.nom}",
          style: AppTypography.labelLarge,
        ),
        backgroundColor: AppColors.background,
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: MapStyles.darkYangoStyle,
            initialCameraPosition: CameraPosition(
              target: userLoc != null
                  ? LatLng(userLoc.latitude, userLoc.longitude)
                  : const LatLng(3.8480, 11.5021), // Yaoundé
              zoom: 13,
            ),
            onMapCreated: (controller) async {
              _mapController = controller;

              // 1️⃣ Ajouter la source GeoJSON (clustering)
              await _mapController!.addSource(
                "pharmacies",
                GeojsonSourceProperties(
                  data: _buildGeoJsonPharmacies(),
                  cluster: true,
                  clusterMaxZoom: 14,
                  clusterRadius: 50,
                ),
              );

              // 2️⃣ Ajouter marqueurs
              await _addPharmacyMarkers();
              _addUserMarker();
            },
          ),

          // Bouton recentrer
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: _centerOnUser,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Charge une image locale pour MapLibre
  Future<Uint8List> _loadImage(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List();
  }

  /// Ajoute le marqueur de l'utilisateur
  void _addUserMarker() {
    final loc = widget.initialUserLocation;
    if (loc == null || _mapController == null) return;

    _mapController!.addSymbol(
      SymbolOptions(
        geometry: LatLng(loc.latitude, loc.longitude),
        iconImage: "circle-15",
        iconSize: 1.5,
        iconColor: "#2563EB",
      ),
    );
  }

  /// Ajoute les marqueurs des pharmacies avec icône personnalisée
  Future<void> _addPharmacyMarkers() async {
    if (_mapController == null) return;

    // 🔹 Charger l’icône UNE SEULE FOIS
    await _mapController!.addImage(
      "pharmacy_icon",
      await _loadImage("assets/icons/pharmacy_marker.png"),
    );

    for (var availability in widget.entry.availabilities) {
      final pharmacy = availability.pharmacy;
      final point = pharmacy.localisation;
      if (point == null) continue;

      _mapController!.addSymbol(
        SymbolOptions(
          geometry: LatLng(point.latitude, point.longitude),
          iconImage: "pharmacy_icon",
          iconSize: 1.2,
          textField: pharmacy.nom,
          textOffset: const Offset(0, 1.5),
        ),
      );
    }
  }

  /// Centre la caméra sur l'utilisateur
  void _centerOnUser() {
    final loc = widget.initialUserLocation;
    if (loc == null || _mapController == null) return;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(loc.latitude, loc.longitude),
        14,
      ),
    );
  }

  /// Construit le GeoJSON des pharmacies (pour clustering)
  String _buildGeoJsonPharmacies() {
    final features = widget.entry.availabilities.map((availability) {
      final point = availability.pharmacy.localisation;
      if (point == null) return null;

      return '''
      {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [${point.longitude}, ${point.latitude}]
        },
        "properties": {
          "name": "${availability.pharmacy.nom}"
        }
      }
      ''';
    }).where((f) => f != null).join(',');

    return '''
    {
      "type": "FeatureCollection",
      "features": [$features]
    }
    ''';
  }
}
