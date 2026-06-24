import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:pharma/models/pharmacy.dart';
import 'package:pharma/services/location_service.dart';
import 'package:pharma/utils/geo_utils.dart';
import 'package:pharma/map/in_app_navigation_page.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicationMapPage extends StatefulWidget {
  const MedicationMapPage({
    super.key,
    required this.entry,
    this.initialUserLocation,
  });

  final MedicationCatalogEntry entry;
  final dynamic initialUserLocation;

  @override
  State<MedicationMapPage> createState() => _MedicationMapPageState();
}

class _MedicationMapPageState extends State<MedicationMapPage>
    with SingleTickerProviderStateMixin {
  static const double _radiusMeters = 5000;
  static const int _pharmacyLimit = 5;

  static const String _cartoVoyagerUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png';
  static const List<String> _cartoSubdomains = ['a', 'b', 'c', 'd'];

  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();

  dynamic _userLocation;
  bool _loadingLocation = false;
  bool _mapReady = false;
  int? _selectedPharmacyIndex;
  StreamSubscription<dynamic>? _positionSubscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _userLocation = widget.initialUserLocation;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
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
    _pulseController.dispose();
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
            content: Text('Impossible de récupérer votre localisation.'),
          ),
        );
      }
    }
  }

  void _recenterMapIfNeeded() {
    if (!_mapReady) return;
    final LatLng? center = _preferredCenter();
    if (center != null) {
      _mapController.move(center, _preferredZoom(center));
    }
  }

  LatLng _defaultCenter() => const LatLng(3.8667, 11.5167); // Yaoundé

  LatLng? _preferredCenter() {
    final dynamic location = _userLocation;
    if (location != null) {
      return LatLng(location.latitude as double, location.longitude as double);
    }
    final availabilities = _availabilitiesWithinRadius();
    if (availabilities.isNotEmpty) {
      final point = availabilities.first.pharmacy.localisation;
      if (point != null) return LatLng(point.latitude, point.longitude);
    }
    if (widget.entry.availabilities.isNotEmpty) {
      final point = widget.entry.availabilities.first.pharmacy.localisation;
      if (point != null) return LatLng(point.latitude, point.longitude);
    }
    return null;
  }

  double _preferredZoom(LatLng center) {
    return _userLocation != null ? 14.0 : 12.5;
  }

  List<MedicationAvailability> _availabilitiesWithinRadius() {
    final dynamic location = _userLocation;
    if (location == null) {
      return [];
    }

    final List<MedicationAvailability> filtered = widget.entry.availabilities
        .where((availability) {
          final point = availability.pharmacy.localisation;
          if (point == null) return false;
          final double distance = GeoUtils.haversineDistance(
            startLat: location.latitude as double,
            startLng: location.longitude as double,
            endLat: point.latitude,
            endLng: point.longitude,
          );
          return distance <= _radiusMeters;
        })
        .toList();

    filtered.sort((a, b) {
      final pointA = a.pharmacy.localisation;
      final pointB = b.pharmacy.localisation;
      final double distanceA = pointA == null
          ? double.infinity
          : GeoUtils.haversineDistance(
              startLat: location.latitude as double,
              startLng: location.longitude as double,
              endLat: pointA.latitude,
              endLng: pointA.longitude,
            );
      final double distanceB = pointB == null
          ? double.infinity
          : GeoUtils.haversineDistance(
              startLat: location.latitude as double,
              startLng: location.longitude as double,
              endLat: pointB.latitude,
              endLng: pointB.longitude,
            );
      return distanceA.compareTo(distanceB);
    });

    return filtered.take(_pharmacyLimit).toList();
  }

  Color _statusColor(StockStatus status) {
    switch (status) {
      case StockStatus.enStock:
        return const Color(0xFF22C55E);
      case StockStatus.stockLimite:
        return const Color(0xFFF59E0B);
      case StockStatus.rupture:
        return const Color(0xFFEF4444);
      case StockStatus.aConfirmer:
        return const Color(0xFF94A3B8);
    }
  }

  String _distanceLabel(Pharmacy pharmacy) {
    final dynamic location = _userLocation;
    if (location == null) return 'Distance inconnue';

    // CORRECTION : pharmacy.localisation est un GeoLocationPoint, accès direct
    final GeoLocationPoint? point = pharmacy.localisation;
    if (point == null) return 'Distance inconnue';

    double startLat;
    double startLng;
    try {
      startLat = (location.latitude as num).toDouble();
      startLng = (location.longitude as num).toDouble();
    } catch (_) {
      return 'Distance inconnue';
    }

    final double distance = GeoUtils.haversineDistance(
      startLat: startLat,
      startLng: startLng,
      endLat: point.latitude,
      endLng: point.longitude,
    );

    if (distance >= 1000) {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
    return '${distance.toStringAsFixed(0)} m';
  }

  List<Marker> _buildMarkers(List<MedicationAvailability> availabilities) {
    final List<Marker> markers = [];

    if (_userLocation != null) {
      final dynamic loc = _userLocation;
      markers.add(
        Marker(
          width: 80,
          height: 80,
          point: LatLng(loc.latitude as double, loc.longitude as double),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.4);
              final opacity = 1.0 - (_pulseController.value * 0.7);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3B82F6)
                              .withOpacity(opacity.clamp(0.0, 1.0)),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                    ),
                  ),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    for (int i = 0; i < availabilities.length; i++) {
      final availability = availabilities[i];
      final point = availability.pharmacy.localisation;
      if (point == null) continue;

      final isSelected = _selectedPharmacyIndex == i;
      final statusColor = _statusColor(availability.medication.status);

      markers.add(
        Marker(
          width: isSelected ? 160 : 50,
          height: isSelected ? 80 : 50,
          point: LatLng(point.latitude, point.longitude),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPharmacyIndex =
                    _selectedPharmacyIndex == i ? null : i;
              });
            },
            child: isSelected
                ? _buildExpandedMarker(availability, statusColor)
                : _buildCompactMarker(statusColor, i + 1),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildCompactMarker(Color statusColor, int index) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: statusColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: statusColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_pharmacy_rounded,
            color: Color(0xFF059669),
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedMarker(
    MedicationAvailability availability,
    Color statusColor,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                availability.pharmacy.nom,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                _distanceLabel(availability.pharmacy),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(12, 8),
          painter: _TrianglePainter(color: statusColor),
        ),
      ],
    );
  }

  // CORRECTION : extrait directement les coordonnées depuis GeoLocationPoint
  Future<void> _openInAppDirections(MedicationAvailability availability) async {
    final pharmacy = availability.pharmacy;
    final GeoLocationPoint? point = pharmacy.localisation;
    if (point == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coordonnées de la pharmacie indisponibles.'),
          ),
        );
      }
      return;
    }

    final double destLat = point.latitude;
    final double destLng = point.longitude;

    dynamic userLoc = widget.initialUserLocation ?? _userLocation;
    if (userLoc == null) {
      try {
        userLoc = await _locationService.tryGetCurrentPosition();
        if (userLoc != null) _userLocation = userLoc;
      } catch (_) {}
    }

    if (userLoc == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Position utilisateur introuvable.')),
        );
      }
      return;
    }

    double startLat;
    double startLng;
    try {
      startLat = (userLoc.latitude as num).toDouble();
      startLng = (userLoc.longitude as num).toDouble();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de déterminer votre position.'),
          ),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InAppNavigationPage(
          startLat: startLat,
          startLng: startLng,
          destLat: destLat,
          destLng: destLng,
          pharmacyName: pharmacy.nom,
          accentColor: _statusColor(availability.medication.status),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<MedicationAvailability> availabilities =
        _availabilitiesWithinRadius();
    final LatLng mapCenter = _preferredCenter() ?? _defaultCenter();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entry.nom,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Rafraîchir la position',
            icon: _loadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF059669),
                    ),
                  )
                : const Icon(Icons.my_location, color: Color(0xFF059669)),
            onPressed: _loadingLocation ? null : () => _refreshLocation(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
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
                    onTap: (_, __) {
                      setState(() {
                        _selectedPharmacyIndex = null;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _cartoVoyagerUrl,
                      subdomains: _cartoSubdomains,
                      userAgentPackageName: 'com.example.pharma',
                      maxZoom: 19,
                      tileProvider: NetworkTileProvider(),
                    ),
                    if (_userLocation != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(
                              (_userLocation as dynamic).latitude as double,
                              (_userLocation as dynamic).longitude as double,
                            ),
                            color: const Color(0xFF059669).withOpacity(0.06),
                            borderColor:
                                const Color(0xFF059669).withOpacity(0.25),
                            borderStrokeWidth: 2,
                            radius: _radiusMeters,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _buildMarkers(availabilities)),
                  ],
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Column(
                    children: [
                      _buildMapControl(
                        icon: Icons.add,
                        onTap: () {
                          if (_mapReady) {
                            _mapController.move(
                              _mapController.camera.center,
                              _mapController.camera.zoom + 1,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.remove,
                        onTap: () {
                          if (_mapReady) {
                            _mapController.move(
                              _mapController.camera.center,
                              _mapController.camera.zoom - 1,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.my_location,
                        onTap: () => _refreshLocation(),
                        accent: true,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_pharmacy_rounded,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${availabilities.length} pharmacie${availabilities.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        if (_userLocation != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 14,
                            color: const Color(0xFFE2E8F0),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Rayon ${(_radiusMeters / 1000).toStringAsFixed(0)} km',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomPanel(availabilities),
        ],
      ),
    );
  }

  Widget _buildMapControl({
    required IconData icon,
    required VoidCallback onTap,
    bool accent = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent ? const Color(0xFF059669) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: accent ? Colors.white : const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(List<MedicationAvailability> availabilities) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pharmacies à proximité',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (_userLocation != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(_radiusMeters / 1000).toStringAsFixed(0)} km',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (availabilities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucune pharmacie dans un rayon de 5 km.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final availability = availabilities[index];
                  final pharmacy = availability.pharmacy;
                  final isSelected = _selectedPharmacyIndex == index;
                  final statusColor =
                      _statusColor(availability.medication.status);

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPharmacyIndex = index;
                      });
                      // CORRECTION : accès direct via GeoLocationPoint
                      final point = pharmacy.localisation;
                      if (point != null && _mapReady) {
                        _mapController.move(
                          LatLng(point.latitude, point.longitude),
                          15.5,
                        );
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF059669).withOpacity(0.04)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF059669)
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.local_pharmacy_rounded,
                                  color: Color(0xFF059669),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  pharmacy.nom,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                availability.medication.status.label,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.directions_walk,
                                    size: 14,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _distanceLabel(pharmacy),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () =>
                                    _openInAppDirections(availability),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.directions,
                                    size: 16,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, _) => const SizedBox(width: 10),
                itemCount: availabilities.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
