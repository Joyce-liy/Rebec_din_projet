import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:pharma/map/custom_map_theme.dart';

// ─────────────────────────────────────────────
// Data model for one OSRM turn-by-turn step
// ─────────────────────────────────────────────
class _NavStep {
  final String instruction;
  final String maneuverType;     // 'turn', 'depart', 'arrive', 'roundabout', etc.
  final String maneuverModifier; // 'left', 'right', 'straight', 'slight left', etc.
  final double distanceMeters;
  final double durationSeconds;
  final LatLng location;

  const _NavStep({
    required this.instruction,
    required this.maneuverType,
    required this.maneuverModifier,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
  });

  factory _NavStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] as Map<String, dynamic>? ?? {};
    final loc = maneuver['location'] as List<dynamic>?;
    final lat = loc != null && loc.length > 1 ? (loc[1] as num).toDouble() : 0.0;
    final lng = loc != null && loc.isNotEmpty  ? (loc[0] as num).toDouble() : 0.0;

    return _NavStep(
      instruction: json['name'] as String? ?? '',
      maneuverType: maneuver['type'] as String? ?? '',
      maneuverModifier: maneuver['modifier'] as String? ?? 'straight',
      distanceMeters: (json['distance'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration'] as num?)?.toDouble() ?? 0.0,
      location: LatLng(lat, lng),
    );
  }
}

// ─────────────────────────────────────────────
// Navigation modes
// ─────────────────────────────────────────────
enum _NavMode { overview, navigating, arrived }

class InAppNavigationPage extends StatefulWidget {
  final double startLat;
  final double startLng;
  final double destLat;
  final double destLng;
  final String? pharmacyName;
  final Color? accentColor;

  const InAppNavigationPage({
    super.key,
    required this.startLat,
    required this.startLng,
    required this.destLat,
    required this.destLng,
    this.pharmacyName,
    this.accentColor,
  });

  @override
  State<InAppNavigationPage> createState() => _InAppNavigationPageState();
}

class _InAppNavigationPageState extends State<InAppNavigationPage>
    with TickerProviderStateMixin {

  // ── Map ──────────────────────────────────────
  final MapController _mapController = MapController();
  bool _mapReady = false;

  // ── Route data ───────────────────────────────
  late LatLng _destination;
  List<LatLng> _routePoints = [];
  List<LatLng> _remainingPoints = [];
  List<_NavStep> _steps = [];
  double? _totalDistanceMeters;
  double? _totalDurationSeconds;
  bool _loadingRoute = true;
  bool _fallbackRoute = false;
  String? _routeError;

  // ── Live position ────────────────────────────
  LatLng _currentPosition = LatLng(0, 0);
  double _currentBearing = 0.0;
  StreamSubscription<Position>? _positionSub;
  bool _hasGps = false;
  bool _followUser = false; // true while navigating = camera locks on user

  // ── Navigation state ─────────────────────────
  _NavMode _mode = _NavMode.overview;
  int _currentStepIndex = 0;
  double _distanceToNextStep = 0;
  double _remainingDistanceMeters = 0;
  double _remainingDurationSeconds = 0;
  late AnimationController _pulseAnim;
  late AnimationController _bannerAnim;

  // ── Recalculation ────────────────────────────
  bool _recalculating = false;
  static const double _offRouteThresholdMeters = 50.0;
  static const double _stepReachedThresholdMeters = 25.0;
  static const double _arrivalThresholdMeters = 30.0;

  // ── TTS ──────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  int _lastSpokenStepIndex = -1;

  // ── Theme ────────────────────────────────────
  Color get _accent => widget.accentColor ?? const Color(0xFF059669);
  Color get _startColor => const Color(0xFF2563EB);
  Color get _warnColor => const Color(0xFFF59E0B);

  String get _pharmacyName {
    final n = widget.pharmacyName?.trim();
    return (n == null || n.isEmpty) ? 'Pharmacie' : n;
  }

  // ─────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _destination = LatLng(widget.destLat, widget.destLng);
    _currentPosition = LatLng(widget.startLat, widget.startLng);

    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _bannerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _initTts();
    _fetchRoute();
    _startPositionStream();
  }

  @override
  void dispose() {
    _tts.stop();
    _positionSub?.cancel();
    _pulseAnim.dispose();
    _bannerAnim.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // TTS
  // ─────────────────────────────────────────────
  Future<void> _initTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.50);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  String _buildVoiceInstruction(_NavStep step, {double? distanceMeters}) {
    final dist = distanceMeters ?? step.distanceMeters;
    final distStr = dist < 1000
        ? 'dans ${dist.round()} mètres'
        : 'dans ${(dist / 1000).toStringAsFixed(1)} kilomètres';

    if (step.maneuverType == 'arrive') {
      return 'Vous êtes arrivé à destination : $_pharmacyName';
    }
    if (step.maneuverType == 'depart') {
      return 'Départ. Continuez tout droit $distStr.';
    }
    if (step.maneuverType == 'roundabout' ||
        step.maneuverType == 'rotary') {
      return 'Prenez le rond-point $distStr.';
    }

    final road = step.instruction.trim().isNotEmpty
        ? 'sur ${step.instruction}'
        : '';

    switch (step.maneuverModifier) {
      case 'left':
        return 'Tournez à gauche $road $distStr.';
      case 'right':
        return 'Tournez à droite $road $distStr.';
      case 'sharp left':
        return 'Virez à gauche $road $distStr.';
      case 'sharp right':
        return 'Virez à droite $road $distStr.';
      case 'slight left':
        return 'Légèrement à gauche $road $distStr.';
      case 'slight right':
        return 'Légèrement à droite $road $distStr.';
      case 'uturn':
        return 'Faites demi-tour $road $distStr.';
      default:
        return 'Continuez tout droit $road $distStr.';
    }
  }

  // ─────────────────────────────────────────────
  // GPS stream
  // ─────────────────────────────────────────────
  Future<void> _startPositionStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5, // update every 5 m
      ),
    ).listen((pos) {
      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _hasGps = true;
        _currentBearing = pos.heading;
        _currentPosition = newPos;
      });

      if (_mode == _NavMode.navigating) {
        _updateNavigation(newPos);
        if (_followUser && _mapReady) {
          _mapController.moveAndRotate(newPos, _mapController.camera.zoom, -pos.heading);
        }
      }
    });
  }

  // ─────────────────────────────────────────────
  // Route fetching (OSRM with steps)
  // ─────────────────────────────────────────────
  Future<void> _fetchRoute({LatLng? from}) async {
    final origin = from ?? _currentPosition;
    setState(() {
      _loadingRoute = true;
      _routeError = null;
    });

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude.toStringAsFixed(7)},${origin.latitude.toStringAsFixed(7)};'
      '${widget.destLng.toStringAsFixed(7)},${widget.destLat.toStringAsFixed(7)}'
      '?overview=full&geometries=geojson&steps=true&annotations=false',
    );

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) throw Exception('No route');

      final route = routes.first as Map<String, dynamic>;

      // ── Geometry ──────────────────────────────
      final coords =
          (route['geometry']?['coordinates'] as List<dynamic>?) ?? [];
      final routePoints = <LatLng>[];
      for (final c in coords) {
        if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
          routePoints.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
        }
      }
      if (routePoints.length < 2) throw Exception('Geometry too short');

      // ── Steps ─────────────────────────────────
      final legs = route['legs'] as List<dynamic>? ?? [];
      final steps = <_NavStep>[];
      for (final leg in legs) {
        final legSteps = (leg as Map<String, dynamic>)['steps'] as List<dynamic>? ?? [];
        for (final s in legSteps) {
          steps.add(_NavStep.fromJson(s as Map<String, dynamic>));
        }
      }

      if (!mounted) return;
      setState(() {
        _routePoints = routePoints;
        _remainingPoints = List.from(routePoints);
        _steps = steps;
        _totalDistanceMeters = (route['distance'] as num?)?.toDouble();
        _totalDurationSeconds = (route['duration'] as num?)?.toDouble();
        _remainingDistanceMeters = _totalDistanceMeters ?? 0;
        _remainingDurationSeconds = _totalDurationSeconds ?? 0;
        _currentStepIndex = 0;
        _fallbackRoute = false;
        _loadingRoute = false;
        _recalculating = false;
      });
      _fitRoute();
    } catch (e) {
      if (!mounted) return;
      _applyFallbackRoute(origin);
    }
  }

  void _applyFallbackRoute(LatLng origin) {
    final dist = _haversine(origin, _destination);
    final pts = _generateStraightLine(origin, _destination);
    setState(() {
      _routePoints = pts;
      _remainingPoints = List.from(pts);
      _steps = [
        _NavStep(
          instruction: 'Continuer tout droit',
          maneuverType: 'depart',
          maneuverModifier: 'straight',
          distanceMeters: dist,
          durationSeconds: dist / 10,
          location: origin,
        ),
        _NavStep(
          instruction: _pharmacyName,
          maneuverType: 'arrive',
          maneuverModifier: 'straight',
          distanceMeters: 0,
          durationSeconds: 0,
          location: _destination,
        ),
      ];
      _totalDistanceMeters = dist;
      _totalDurationSeconds = dist / 10;
      _remainingDistanceMeters = dist;
      _remainingDurationSeconds = dist / 10;
      _currentStepIndex = 0;
      _fallbackRoute = true;
      _loadingRoute = false;
      _recalculating = false;
    });
    _fitRoute();
  }

  List<LatLng> _generateStraightLine(LatLng a, LatLng b, {int points = 20}) {
    final result = <LatLng>[];
    for (int i = 0; i <= points; i++) {
      final t = i / points;
      result.add(LatLng(
        a.latitude  + (b.latitude  - a.latitude)  * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ));
    }
    return result;
  }

  // ─────────────────────────────────────────────
  // Navigation logic (step progression + off-route)
  // ─────────────────────────────────────────────
  void _updateNavigation(LatLng pos) {
    if (_steps.isEmpty) return;

    // ── Arrivée ───────────────────────────────
    final distToDest = _haversine(pos, _destination);
    if (distToDest <= _arrivalThresholdMeters) {
      setState(() { _mode = _NavMode.arrived; });
      _bannerAnim.forward();
      _positionSub?.cancel();
      _speak('Vous êtes arrivé à destination : $_pharmacyName');
      return;
    }

    // ── Avancement d'étape ────────────────────
    if (_currentStepIndex < _steps.length - 1) {
      final nextStep = _steps[_currentStepIndex + 1];
      final distToNext = _haversine(pos, nextStep.location);
      _distanceToNextStep = distToNext;

      if (distToNext <= _stepReachedThresholdMeters) {
        setState(() { _currentStepIndex++; });
        _bannerAnim
          ..reset()
          ..forward();

        // Annonce vocale de la nouvelle étape
        if (_currentStepIndex != _lastSpokenStepIndex) {
          _lastSpokenStepIndex = _currentStepIndex;
          _speak(_buildVoiceInstruction(_steps[_currentStepIndex]));
        }
      } else {
        // Pré-annonce à 150 m de la prochaine étape
        if (distToNext <= 150 &&
            distToNext > _stepReachedThresholdMeters &&
            _currentStepIndex + 1 != _lastSpokenStepIndex) {
          _lastSpokenStepIndex = _currentStepIndex + 1;
          _speak(_buildVoiceInstruction(
            nextStep,
            distanceMeters: distToNext,
          ));
        }
      }
    }

    // ── Recalcul hors-route ───────────────────
    if (!_recalculating && !_fallbackRoute) {
      final distToRoute = _distanceToPolyline(pos, _remainingPoints);
      if (distToRoute > _offRouteThresholdMeters) {
        setState(() { _recalculating = true; });
        _speak('Recalcul de l\'itinéraire en cours.');
        _fetchRoute(from: pos);
        return;
      }
    }

    // ── Mise à jour distance/durée restante ───
    double remaining = 0;
    double remainingDur = 0;
    for (int i = _currentStepIndex; i < _steps.length; i++) {
      remaining += _steps[i].distanceMeters;
      remainingDur += _steps[i].durationSeconds;
    }
    setState(() {
      _remainingDistanceMeters = remaining;
      _remainingDurationSeconds = remainingDur;
    });
  }

  // ─────────────────────────────────────────────
  // Camera helpers
  // ─────────────────────────────────────────────
  void _fitRoute() {
    if (!_mapReady || _routePoints.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [..._routePoints, _currentPosition, _destination],
          padding: const EdgeInsets.fromLTRB(52, 130, 52, 240),
          maxZoom: 16,
        ),
      );
    });
  }

  void _startNavigation() {
    setState(() {
      _mode = _NavMode.navigating;
      _followUser = true;
      _currentStepIndex = 0;
      _lastSpokenStepIndex = -1;
    });
    _bannerAnim.forward();
    if (_mapReady) {
      _mapController.moveAndRotate(_currentPosition, 17.5, -_currentBearing);
    }

    // Annonce vocale de départ
    if (_steps.isNotEmpty) {
      _speak(_buildVoiceInstruction(_steps[0]));
      _lastSpokenStepIndex = 0;
    }
  }

  void _stopNavigation() {
    _tts.stop();
    setState(() {
      _mode = _NavMode.overview;
      _followUser = false;
    });
    _bannerAnim.reset();
    _mapController.moveAndRotate(
      _mapController.camera.center,
      _mapController.camera.zoom,
      0,
    );
    _fitRoute();
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    final z = (_mapController.camera.zoom + delta).clamp(3.0, 19.0);
    _mapController.move(_mapController.camera.center, z);
  }

  // ─────────────────────────────────────────────
  // Geometry utilities
  // ─────────────────────────────────────────────
  double _haversine(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final v = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(v), math.sqrt(1 - v));
  }

  double _rad(double deg) => deg * math.pi / 180;

  double _distanceToPolyline(LatLng p, List<LatLng> poly) {
    if (poly.isEmpty) return double.infinity;
    double minDist = double.infinity;
    for (final pt in poly) {
      final d = _haversine(p, pt);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  // ─────────────────────────────────────────────
  // Formatting
  // ─────────────────────────────────────────────
  String _formatDur(double? sec) {
    if (sec == null) return '--';
    final m = math.max(1, (sec / 60).ceil());
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rem = m % 60;
    return rem == 0 ? '${h}h' : '${h}h ${rem}min';
  }

  String _formatDist(double? m) {
    if (m == null) return '--';
    if (m < 1000) return '${m.round()} m';
    final k = m / 1000;
    return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)} km';
  }

  // ─────────────────────────────────────────────
  // Maneuver icon + label helpers
  // ─────────────────────────────────────────────
  IconData _maneuverIcon(_NavStep step) {
    if (step.maneuverType == 'arrive') return Icons.local_pharmacy_rounded;
    if (step.maneuverType == 'depart') return Icons.navigation_rounded;
    if (step.maneuverType == 'roundabout' ||
        step.maneuverType == 'rotary') return Icons.roundabout_left_rounded;
    switch (step.maneuverModifier) {
      case 'left':         return Icons.turn_left_rounded;
      case 'right':        return Icons.turn_right_rounded;
      case 'sharp left':   return Icons.turn_sharp_left_rounded;
      case 'sharp right':  return Icons.turn_sharp_right_rounded;
      case 'slight left':  return Icons.turn_slight_left_rounded;
      case 'slight right': return Icons.turn_slight_right_rounded;
      case 'uturn':        return Icons.u_turn_left_rounded;
      default:             return Icons.straight_rounded;
    }
  }

  String _maneuverLabel(_NavStep step) {
    if (step.maneuverType == 'arrive') return 'Arrivée : $_pharmacyName';
    if (step.maneuverType == 'depart') return 'Départ — continuer tout droit';
    if (step.maneuverType == 'roundabout') return 'Prendre le rond-point';

    final road = step.instruction.trim().isNotEmpty
        ? step.instruction
        : 'la route';

    switch (step.maneuverModifier) {
      case 'left':         return 'Tourner à gauche sur $road';
      case 'right':        return 'Tourner à droite sur $road';
      case 'sharp left':   return 'Virer à gauche sur $road';
      case 'sharp right':  return 'Virer à droite sur $road';
      case 'slight left':  return 'Légèrement à gauche sur $road';
      case 'slight right': return 'Légèrement à droite sur $road';
      case 'uturn':        return 'Faire demi-tour sur $road';
      default:             return 'Continuer sur $road';
    }
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCameraFit: CameraFit.coordinates(
                coordinates: [_currentPosition, _destination],
                padding: const EdgeInsets.fromLTRB(52, 130, 52, 240),
                maxZoom: 16,
              ),
              minZoom: 3,
              maxZoom: 19,
              backgroundColor: const Color(0xFFEFF6F5),
              onMapReady: () {
                _mapReady = true;
                _fitRoute();
              },
              onTap: (_, __) {
                if (_followUser) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: MapStyles.cartoVoyagerUrl,
                fallbackUrl: MapStyles.osmStandardUrl,
                subdomains: MapStyles.cartoSubdomains,
                userAgentPackageName: 'com.example.pharma',
                maxZoom: 19,
                tileProvider: NetworkTileProvider(),
              ),
              // Route polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Full route faint background
                    Polyline(
                      points: _routePoints,
                      color: _fallbackRoute
                          ? _warnColor.withOpacity(0.25)
                          : _accent.withOpacity(0.20),
                      strokeWidth: 8,
                    ),
                    // Active/remaining route
                    Polyline(
                      points: _routePoints,
                      color: _fallbackRoute ? _warnColor : _accent,
                      strokeWidth: 6,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2.5,
                      pattern: _fallbackRoute
                          ? StrokePattern.dashed(segments: [12, 8])
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),
              // Destination circle
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _destination,
                    radius: 44,
                    color: _accent.withOpacity(0.08),
                    borderColor: _accent.withOpacity(0.30),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(markers: _buildMarkers()),
            ],
          ),

          // ── Top gradient ─────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, -0.4),
                    colors: [
                      Colors.black.withOpacity(0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Top bar (overview) ou maneuver banner (navigating) ──
          if (_mode == _NavMode.overview || _mode == _NavMode.arrived)
            _buildTopBar(context)
          else
            _buildManeuverBanner(context),

          // ── Map control buttons ───────────────
          _buildMapControls(context),

          // ── Bottom panel ─────────────────────
          _buildBottomPanel(context),

          // ── Loading overlay ───────────────────
          if (_loadingRoute)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.white.withOpacity(0.10),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _recalculating
                              ? 'Recalcul de l\'itinéraire…'
                              : 'Calcul de l\'itinéraire…',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Arrived overlay ───────────────────
          if (_mode == _NavMode.arrived) _buildArrivedOverlay(context),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Markers
  // ─────────────────────────────────────────────
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // User position with heading arrow
    markers.add(
      Marker(
        point: _currentPosition,
        width: 72,
        height: 72,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) {
            final pulse = 1.0 + _pulseAnim.value * 0.5;
            final opacity = 1.0 - _pulseAnim.value * 0.6;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _startColor.withOpacity(opacity.clamp(0, 1)),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: _rad(_currentBearing),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _startColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: _startColor.withOpacity(0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    // Destination marker
    markers.add(
      Marker(
        point: _destination,
        width: 140,
        height: 88,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 130),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _accent.withOpacity(0.25), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                _pharmacyName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.40),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_pharmacy_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );

    // Next-step waypoint pin (only while navigating)
    if (_mode == _NavMode.navigating &&
        _currentStepIndex + 1 < _steps.length) {
      final next = _steps[_currentStepIndex + 1];
      if (next.maneuverType != 'arrive') {
        markers.add(
          Marker(
            point: next.location,
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: Icon(_maneuverIcon(next), color: Colors.white, size: 16),
            ),
          ),
        );
      }
    }

    return markers;
  }

  // ─────────────────────────────────────────────
  // Top bar (overview mode)
  // ─────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 10,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _ControlBtn(
              icon: Icons.arrow_back_rounded,
              onTap: () => Navigator.of(context).maybePop(),
              fgColor: const Color(0xFF0F172A),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Itinéraire vers',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _pharmacyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (_fallbackRoute)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _warnColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _warnColor.withOpacity(0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: _warnColor),
                    const SizedBox(width: 4),
                    Text(
                      'Tracé direct',
                      style: TextStyle(
                          color: _warnColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Maneuver banner (navigation mode)
  // ─────────────────────────────────────────────
  Widget _buildManeuverBanner(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final step = _steps.isNotEmpty && _currentStepIndex < _steps.length
        ? _steps[_currentStepIndex]
        : null;
    final nextStep = _steps.isNotEmpty && _currentStepIndex + 1 < _steps.length
        ? _steps[_currentStepIndex + 1]
        : null;

    return Positioned(
      top: top + 8,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _bannerAnim,
          curve: Curves.easeOutCubic,
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main maneuver card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Maneuver icon (large)
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        step != null ? _maneuverIcon(step) : Icons.navigation_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDist(_distanceToNextStep > 0
                                ? _distanceToNextStep
                                : step?.distanceMeters),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            step != null ? _maneuverLabel(step) : 'Continuer',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Stop nav button
                    _ControlBtn(
                      icon: Icons.close_rounded,
                      onTap: _stopNavigation,
                      fgColor: Colors.white70,
                      bgColor: Colors.white12,
                      size: 38,
                    ),
                  ],
                ),
              ),

              // Next step mini-hint
              if (nextStep != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Ensuite : ',
                        style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      Icon(_maneuverIcon(nextStep), color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _maneuverLabel(nextStep),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Map controls
  // ─────────────────────────────────────────────
  Widget _buildMapControls(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      right: 12,
      top: top + 100,
      child: Column(
        children: [
          _ControlBtn(icon: Icons.add_rounded, onTap: () => _zoomBy(1)),
          const SizedBox(height: 8),
          _ControlBtn(icon: Icons.remove_rounded, onTap: () => _zoomBy(-1)),
          const SizedBox(height: 8),
          _ControlBtn(
            icon: _followUser
                ? Icons.my_location_rounded
                : Icons.location_searching_rounded,
            onTap: () {
              setState(() => _followUser = !_followUser);
              if (_followUser && _mapReady) {
                _mapController.moveAndRotate(
                    _currentPosition, 17.5, -_currentBearing);
              }
            },
            fgColor: _followUser ? _accent : const Color(0xFF475569),
          ),
          const SizedBox(height: 8),
          _ControlBtn(
            icon: Icons.fit_screen_rounded,
            onTap: _fitRoute,
            fgColor: const Color(0xFF475569),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Bottom panel
  // ─────────────────────────────────────────────
  Widget _buildBottomPanel(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    if (_mode == _NavMode.navigating) {
      return _buildNavigatingPanel(context, bottom);
    }
    return _buildOverviewPanel(context, bottom);
  }

  Widget _buildOverviewPanel(BuildContext context, double bottom) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom + 12,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.13),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.local_pharmacy_rounded, color: _accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pharmacyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fallbackRoute
                            ? 'Tracé direct · sans accès réseau OSRM'
                            : 'Itinéraire routier calculé',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _fallbackRoute ? _warnColor : const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Metrics row
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    icon: Icons.schedule_rounded,
                    label: 'Durée',
                    value: _formatDur(_totalDurationSeconds),
                    color: _accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.straighten_rounded,
                    label: 'Distance',
                    value: _formatDist(_totalDistanceMeters),
                    color: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    icon: Icons.turn_slight_right_rounded,
                    label: 'Étapes',
                    value: _steps.isEmpty ? '--' : '${_steps.length}',
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Steps list (collapsed, up to 3)
            if (_steps.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _steps.length && i < 3; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(_maneuverIcon(_steps[i]),
                                size: 20,
                                color: i == 0 ? _accent : const Color(0xFF64748B)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _maneuverLabel(_steps[i]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: i == 0
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF475569),
                                  fontSize: 13,
                                  fontWeight: i == 0
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              _formatDist(_steps[i].distanceMeters),
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_steps.length > 3)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text(
                          '+ ${_steps.length - 3} étapes supplémentaires',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            // START NAVIGATION button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loadingRoute ? null : _startNavigation,
                icon: const Icon(Icons.navigation_rounded, size: 22),
                label: const Text(
                  'Démarrer la navigation',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accent.withOpacity(0.40),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigatingPanel(BuildContext context, double bottom) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottom + 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDur(_remainingDurationSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDist(_remainingDistanceMeters),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Re-lock camera button
            if (!_followUser)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ControlBtn(
                  icon: Icons.my_location_rounded,
                  onTap: () {
                    setState(() => _followUser = true);
                    _mapController.moveAndRotate(
                        _currentPosition, 17.5, -_currentBearing);
                  },
                  fgColor: Colors.white,
                  bgColor: _accent.withOpacity(0.25),
                  size: 42,
                ),
              ),
            // Stop navigation
            _ControlBtn(
              icon: Icons.stop_rounded,
              onTap: _stopNavigation,
              fgColor: Colors.white,
              bgColor: const Color(0xFFEF4444).withOpacity(0.85),
              size: 42,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Arrived overlay
  // ─────────────────────────────────────────────
  Widget _buildArrivedOverlay(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: Colors.black.withOpacity(0.50),
          alignment: Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded, color: _accent, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vous êtes arrivé !',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _pharmacyName,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Terminer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reusable small widgets
// ─────────────────────────────────────────────
class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color fgColor;
  final Color? bgColor;
  final double size;

  const _ControlBtn({
    required this.icon,
    required this.onTap,
    this.fgColor = const Color(0xFF0F172A),
    this.bgColor,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor ?? Colors.white,
      borderRadius: BorderRadius.circular(9),
      elevation: bgColor == null ? 4 : 0,
      shadowColor: Colors.black.withOpacity(0.16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: fgColor, size: size * 0.52),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}