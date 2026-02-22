import 'dart:math';

/// Utility helpers for geographic calculations.
class GeoUtils {
  GeoUtils._();

  static const double _earthRadiusMeters = 6371000; // Mean Earth radius

  /// Calculates the Haversine distance between two GPS coordinates.
  ///
  /// Returns distance in meters.
  static double haversineDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final double dLat = _toRadians(endLat - startLat);
    final double dLng = _toRadians(endLng - startLng);
    final double originLat = _toRadians(startLat);
    final double destinationLat = _toRadians(endLat);

    final double a = pow(sin(dLat / 2), 2) +
        pow(sin(dLng / 2), 2) * cos(originLat) * cos(destinationLat);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadiusMeters * c;
  }

  /// Projects a new GPS coordinate from [startLat], [startLng]
  /// following the given [bearingDegrees] and travelling [distanceMeters].
  static (double lat, double lng) projectCoordinate({
    required double startLat,
    required double startLng,
    required double distanceMeters,
    required double bearingDegrees,
  }) {
    final double angularDistance = distanceMeters / _earthRadiusMeters;
    final double bearing = _toRadians(bearingDegrees);

    final double originLat = _toRadians(startLat);
    final double originLng = _toRadians(startLng);

    final double destinationLat = asin(
      sin(originLat) * cos(angularDistance) +
          cos(originLat) * sin(angularDistance) * cos(bearing),
    );

    final double destinationLng = originLng + atan2(
      sin(bearing) * sin(angularDistance) * cos(originLat),
      cos(angularDistance) - sin(originLat) * sin(destinationLat),
    );

    return (
      _toDegrees(destinationLat),
      _normalizeLongitude(_toDegrees(destinationLng)),
    );
  }


  /// Computes the initial bearing in degrees from the start point to the end point.
  static double initialBearing({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final double originLat = _toRadians(startLat);
    final double destinationLat = _toRadians(endLat);
    final double deltaLng = _toRadians(endLng - startLng);

    final double y = sin(deltaLng) * cos(destinationLat);
    final double x = cos(originLat) * sin(destinationLat) -
        sin(originLat) * cos(destinationLat) * cos(deltaLng);

    final double bearing = _toDegrees(atan2(y, x));
    return (bearing + 360) % 360;
  }

  static double _toRadians(double degrees) => degrees * (pi / 180);

  static double _toDegrees(double radians) => radians * (180 / pi);

  static double _normalizeLongitude(double longitude) {
    var result = longitude;
    while (result < -180) {
      result += 360;
    }
    while (result > 180) {
      result -= 360;
    }
    return result;
  }
}
