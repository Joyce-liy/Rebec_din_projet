import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/utils/geo_utils.dart';

class MedicationMapPage extends StatefulWidget {
  const MedicationMapPage({
    super.key,
    required this.entry,
    this.initialUserLocation,
  });

  final MedicationCatalogEntry entry;
  final GeoPoint? initialUserLocation;

  @override
  State<MedicationMapPage> createState() => _MedicationMapPageState();
}

class _MedicationMapPageState extends State<MedicationMapPage> {
  static const double _radiusMeters = 5000;

  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  GeoPoint? _userLocation;
  bool _loadingLocation = false;
  bool _mapReady = false;
  StreamSubscription<GeoPoint>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _userLocation = widget.initialUserLocation;
    _refreshLocation(silent: true);
    _positionSubscription = _locationService
        .positionStream(accuracy: LocationAccuracy.high)
        .listen((geoPoint) {
      if (!mounted) return;
      setState(() {
        _userLocation = geoPoint;
      });
      _recenterMapIfNeeded();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshLocation({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingLocation = true;
      });
    }

    try {
      final GeoPoint? location = await _locationService.tryGetCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLocation = location ?? _userLocation;
        _loadingLocation = false;
      });
      _recenterMapIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
      });
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de recuperer votre localisation.'),
          ),
        );
      }
    }
  }

  void _recenterMapIfNeeded() {
    if (!_mapReady) {
      return;
    }
    final LatLng? center = _preferredCenter();
    if (center != null) {
      _mapController.move(center, _preferredZoom(center));
    }
  }

  LatLng _defaultCenter() => const LatLng(3.8667, 11.5167); // Yaoundé

  LatLng? _preferredCenter() {
    final GeoPoint? location = _userLocation;
    if (location != null) {
      return LatLng(location.latitude, location.longitude);
    }
    final availabilities = _availabilitiesWithinRadius();
    if (availabilities.isNotEmpty) {
      final Pharmacy pharmacy = availabilities.first.pharmacy;
      return LatLng(pharmacy.latitude, pharmacy.longitude);
    }
    if (widget.entry.availabilities.isNotEmpty) {
      final Pharmacy pharmacy = widget.entry.availabilities.first.pharmacy;
      return LatLng(pharmacy.latitude, pharmacy.longitude);
    }
    return null;
  }

  double _preferredZoom(LatLng center) {
    // If user location available, zoom closer
    return _userLocation != null ? 14.0 : 12.5;
  }

  List<MedicationAvailability> _availabilitiesWithinRadius() {
    final GeoPoint? location = _userLocation;
    if (location == null) {
      return List<MedicationAvailability>.from(widget.entry.availabilities);
    }

    final List<MedicationAvailability> filtered = widget.entry.availabilities
        .where((availability) {
      final double distance = GeoUtils.haversineDistance(
        startLat: location.latitude,
        startLng: location.longitude,
        endLat: availability.pharmacy.latitude,
        endLng: availability.pharmacy.longitude,
      );
      return distance <= _radiusMeters;
    }).toList();

    filtered.sort((a, b) {
      final double distanceA = GeoUtils.haversineDistance(
        startLat: location.latitude,
        startLng: location.longitude,
        endLat: a.pharmacy.latitude,
        endLng: a.pharmacy.longitude,
      );
      final double distanceB = GeoUtils.haversineDistance(
        startLat: location.latitude,
        startLng: location.longitude,
        endLat: b.pharmacy.latitude,
        endLng: b.pharmacy.longitude,
      );
      return distanceA.compareTo(distanceB);
    });

    return filtered;
  }

  Color _statusColor(StockStatus status) {
    switch (status) {
      case StockStatus.enStock:
        return Colors.green;
      case StockStatus.stockLimite:
        return Colors.orange;
      case StockStatus.rupture:
        return Colors.red;
    }
  }

  String _distanceLabel(Pharmacy pharmacy) {
    final GeoPoint? location = _userLocation;
    if (location == null) {
      return 'Distance inconnue';
    }
    final double distance = GeoUtils.haversineDistance(
      startLat: location.latitude,
      startLng: location.longitude,
      endLat: pharmacy.latitude,
      endLng: pharmacy.longitude,
    );
    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.toStringAsFixed(0)} m';
  }

  List<Marker> _buildMarkers(List<MedicationAvailability> availabilities) {
    final List<Marker> markers = [];

    if (_userLocation != null) {
      markers.add(
        Marker(
          width: 60,
          height: 60,
          point: LatLng(_userLocation!.latitude, _userLocation!.longitude),
          child: const Icon(
            Icons.my_location,
            color: Colors.blueAccent,
            size: 30,
          ),
        ),
      );
    }

    for (final availability in availabilities) {
      markers.add(
        Marker(
          width: 70,
          height: 70,
          point: LatLng(
            availability.pharmacy.latitude,
            availability.pharmacy.longitude,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_pharmacy,
                color: _statusColor(availability.medication.status),
                size: 28,
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  availability.pharmacy.nom,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final List<MedicationAvailability> availabilities =
        _availabilitiesWithinRadius();
    final LatLng mapCenter = _preferredCenter() ?? _defaultCenter();

    return Scaffold(
      appBar: AppBar(
        title: Text('Carte - ${widget.entry.nom} (${widget.entry.dosage})'),
        actions: [
          IconButton(
            tooltip: 'Rafraichir la position',
            icon: _loadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            onPressed: _loadingLocation ? null : () => _refreshLocation(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: _preferredZoom(mapCenter),
                onMapReady: () {
                  setState(() {
                    _mapReady = true;
                  });
                  _recenterMapIfNeeded();
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.pharma',
                ),
                if (_userLocation != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: LatLng(
                          _userLocation!.latitude,
                          _userLocation!.longitude,
                        ),
                        color: Colors.blue.withOpacity(0.15),
                        borderColor: Colors.blueAccent.withOpacity(0.6),
                        borderStrokeWidth: 2,
                        radius: _radiusMeters,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _buildMarkers(availabilities)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: const Border(
                top: BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pharmacies à proximité',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _userLocation != null
                          ? 'Rayon de ${( _radiusMeters / 1000).toStringAsFixed(1)} km'
                          : 'Activez la localisation',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_userLocation == null)
                  const Text(
                    'Votre position n\'est pas disponible. Affichage de toutes les officines.',
                    style: TextStyle(color: Colors.orange),
                  ),
                if (availabilities.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Aucune pharmacie dans un rayon de 5 km. Étendez votre recherche ou rafraîchissez la position.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final availability = availabilities[index];
                        final pharmacy = availability.pharmacy;
                        return Container(
                          width: 220,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pharmacy.nom,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                pharmacy.quartier,
                                style: const TextStyle(color: Colors.black54),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: _statusColor(availability.medication.status),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    availability.medication.status.label,
                                    style: TextStyle(
                                      color: _statusColor(
                                          availability.medication.status),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Distance : ${_distanceLabel(pharmacy)}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const Spacer(),
                              Text(
                                'Qté: ${availability.medication.quantite}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (context, _) => const SizedBox(width: 12),
                      itemCount: availabilities.length,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
